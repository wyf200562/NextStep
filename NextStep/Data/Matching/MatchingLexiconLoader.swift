import Foundation

/// Why the bundled matching lexicons could not be loaded.
nonisolated enum MatchingLexiconError: Error, Equatable {
    case missingResource(String)
    case unreadableResource(String)
    case malformedJSON(String)
    case missingRequiredField(resource: String, index: Int, field: String)
    case duplicateID(resource: String, id: String)
}

/// Loads the bundled skill, role-direction, and location dictionaries.
///
/// The loader is injectable with a `Bundle` or explicit URLs so tests stay hermetic. A loading
/// failure surfaces as a typed error; the composition root turns it into "matching unavailable".
nonisolated struct MatchingLexiconLoader: Sendable {
    let skillDictionaryURL: URL?
    let roleDirectionURL: URL?
    let locationURL: URL?

    init(
        bundle: Bundle = .main,
        skillDictionaryResource: String = "SkillDictionary",
        roleDirectionResource: String = "RoleDirectionLexicon",
        locationResource: String = "LocationLexicon"
    ) {
        self.skillDictionaryURL = Self.resourceURL(named: skillDictionaryResource, in: bundle)
        self.roleDirectionURL = Self.resourceURL(named: roleDirectionResource, in: bundle)
        self.locationURL = Self.resourceURL(named: locationResource, in: bundle)
    }

    init(skillDictionaryURL: URL?, roleDirectionURL: URL?, locationURL: URL?) {
        self.skillDictionaryURL = skillDictionaryURL
        self.roleDirectionURL = roleDirectionURL
        self.locationURL = locationURL
    }

    /// Loads all three dictionaries from the injected URLs.
    func load() throws -> MatchingLexicon {
        let skillDictionaryData = try Self.data(at: skillDictionaryURL, resource: "SkillDictionary")
        let roleDirectionData = try Self.data(at: roleDirectionURL, resource: "RoleDirectionLexicon")
        let locationData = try Self.data(at: locationURL, resource: "LocationLexicon")
        return try Self.makeLexicon(
            skillDictionaryData: skillDictionaryData,
            roleDirectionData: roleDirectionData,
            locationData: locationData
        )
    }

    /// Builds the full lexicon from in-memory data without touching the file system.
    static func makeLexicon(
        skillDictionaryData: Data,
        roleDirectionData: Data,
        locationData: Data
    ) throws -> MatchingLexicon {
        MatchingLexicon(
            skillDictionary: try makeSkillDictionary(from: skillDictionaryData),
            roleDirectionLexicon: try makeRoleDirectionLexicon(from: roleDirectionData),
            locationLexicon: try makeLocationLexicon(from: locationData)
        )
    }

    // MARK: - Skills

    static func makeSkillDictionary(from data: Data) throws -> SkillDictionary {
        let resource = "SkillDictionary"
        let records: [SkillRecord] = try decode([SkillRecord].self, from: data, resource: resource)

        var skills: [Skill] = []
        var seenIDs: Set<SkillID> = []
        for (index, record) in records.enumerated() {
            let id = try requiredString(record.id, resource: resource, index: index, field: "id")
            let name = try requiredString(record.name, resource: resource, index: index, field: "name")
            let aliases = try requiredValue(
                record.aliases,
                resource: resource,
                index: index,
                field: "aliases"
            )
            let category = try requiredString(
                record.category,
                resource: resource,
                index: index,
                field: "category"
            )
            guard seenIDs.insert(id).inserted else {
                throw MatchingLexiconError.duplicateID(resource: resource, id: id)
            }
            skills.append(
                Skill(
                    id: id,
                    name: name,
                    aliases: aliases.map(MatchingTextNormalizer.normalize).filter { !$0.isEmpty },
                    category: category
                )
            )
        }
        return SkillDictionary(skills: skills)
    }

    // MARK: - Role directions

    static func makeRoleDirectionLexicon(from data: Data) throws -> RoleDirectionLexicon {
        let resource = "RoleDirectionLexicon"
        let records: [DirectionRecord] = try decode([DirectionRecord].self, from: data, resource: resource)

        var directions: [DirectionFamily] = []
        var seenIDs: Set<String> = []
        for (index, record) in records.enumerated() {
            let id = try requiredString(record.id, resource: resource, index: index, field: "id")
            let name = try requiredString(record.name, resource: resource, index: index, field: "name")
            let aliases = try requiredValue(
                record.aliases,
                resource: resource,
                index: index,
                field: "aliases"
            )
            guard seenIDs.insert(id).inserted else {
                throw MatchingLexiconError.duplicateID(resource: resource, id: id)
            }
            directions.append(
                DirectionFamily(
                    id: id,
                    name: name,
                    aliases: aliases.map(MatchingTextNormalizer.normalize).filter { !$0.isEmpty }
                )
            )
        }
        return RoleDirectionLexicon(directions: directions)
    }

    // MARK: - Locations

    static func makeLocationLexicon(from data: Data) throws -> LocationLexicon {
        let resource = "LocationLexicon"
        let records: [LocationRecord] = try decode([LocationRecord].self, from: data, resource: resource)

        var regions: [LocationRegion] = []
        var seenIDs: Set<String> = []
        for (index, record) in records.enumerated() {
            let id = try requiredString(record.id, resource: resource, index: index, field: "id")
            let name = try requiredString(record.name, resource: resource, index: index, field: "name")
            let aliases = try requiredValue(
                record.aliases,
                resource: resource,
                index: index,
                field: "aliases"
            )
            guard seenIDs.insert(id).inserted else {
                throw MatchingLexiconError.duplicateID(resource: resource, id: id)
            }
            regions.append(
                LocationRegion(
                    id: id,
                    name: name,
                    aliases: aliases.map(MatchingTextNormalizer.normalize).filter { !$0.isEmpty },
                    parentID: record.parent
                )
            )
        }
        return LocationLexicon(regions: regions)
    }

    // MARK: - Resource lookup

    private static func resourceURL(named name: String, in bundle: Bundle) -> URL? {
        bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Resources")
    }

    private static func data(at url: URL?, resource: String) throws -> Data {
        guard let url else { throw MatchingLexiconError.missingResource(resource) }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw MatchingLexiconError.unreadableResource(resource)
        }
    }

    // MARK: - Validation

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, resource: String) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw MatchingLexiconError.malformedJSON(resource)
        }
    }

    private static func requiredString(
        _ value: String?,
        resource: String,
        index: Int,
        field: String
    ) throws -> String {
        guard let value else {
            throw MatchingLexiconError.missingRequiredField(
                resource: resource,
                index: index,
                field: field
            )
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MatchingLexiconError.missingRequiredField(
                resource: resource,
                index: index,
                field: field
            )
        }
        return trimmed
    }

    private static func requiredValue<T>(
        _ value: T?,
        resource: String,
        index: Int,
        field: String
    ) throws -> T {
        guard let value else {
            throw MatchingLexiconError.missingRequiredField(
                resource: resource,
                index: index,
                field: field
            )
        }
        return value
    }

    // MARK: - Records

    private struct SkillRecord: Decodable {
        let id: String?
        let name: String?
        let aliases: [String]?
        let category: String?
    }

    private struct DirectionRecord: Decodable {
        let id: String?
        let name: String?
        let aliases: [String]?
    }

    private struct LocationRecord: Decodable {
        let id: String?
        let name: String?
        let aliases: [String]?
        let parent: String?
    }
}
