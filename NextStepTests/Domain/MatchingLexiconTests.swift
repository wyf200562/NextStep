import Foundation
import Testing
@testable import NextStep

@Suite("Matching lexicon loading")
struct MatchingLexiconTests {
    private func skillDictionary(_ json: String) throws -> SkillDictionary {
        try MatchingLexiconLoader.makeSkillDictionary(from: Data(json.utf8))
    }

    @Test func decodesSkillsInFileOrderWithNormalizedAliasesAndCategories() throws {
        let dictionary = try skillDictionary(
            """
            [
              {"id":"swift","name":"Swift","aliases":["Swift","ＳＷＩＦＴ语言"],"category":"语言"},
              {"id":"swiftui","name":"SwiftUI","aliases":["swiftui","swift ui"],"category":"UI"}
            ]
            """
        )

        #expect(dictionary.skills.map(\.id) == ["swift", "swiftui"])
        #expect(dictionary.skills[0].name == "Swift")
        #expect(dictionary.skills[0].category == "语言")
        #expect(dictionary.skills[0].aliases == ["swift", "swift语言"])
        #expect(dictionary.skills[1].aliases == ["swiftui", "swift ui"])
    }

    @Test(arguments: ["id", "name", "aliases", "category"])
    func skillMissingRequiredFieldFailsLoad(_ field: String) throws {
        var record: [String: Any] = [
            "id": "swift",
            "name": "Swift",
            "aliases": ["swift"],
            "category": "语言",
        ]
        record.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: [record])

        #expect(throws: MatchingLexiconError.self) {
            _ = try MatchingLexiconLoader.makeSkillDictionary(from: data)
        }
    }

    @Test func emptyRequiredStringFailsLoad() throws {
        let json = """
        [{"id":"","name":"Swift","aliases":["swift"],"category":"语言"}]
        """

        #expect(throws: MatchingLexiconError.self) {
            _ = try skillDictionary(json)
        }
    }

    @Test func duplicateSkillIDFailsLoad() throws {
        let json = """
        [
          {"id":"swift","name":"Swift","aliases":["swift"],"category":"语言"},
          {"id":"swift","name":"Swift Again","aliases":["swift2"],"category":"语言"}
        ]
        """

        #expect(throws: MatchingLexiconError.duplicateID(resource: "SkillDictionary", id: "swift")) {
            _ = try skillDictionary(json)
        }
    }

    @Test func crossSkillDuplicateAliasKeepsTheFirstDictionaryEntry() throws {
        let json = """
        [
          {"id":"first","name":"First","aliases":["shared","first"],"category":"测试"},
          {"id":"second","name":"Second","aliases":["shared","second"],"category":"测试"}
        ]
        """

        let dictionary = try skillDictionary(json)

        #expect(dictionary.skillID(forAlias: "shared") == "first")
        #expect(dictionary.skillID(forAlias: "SHARED") == "first")
        #expect(dictionary.skill(named: "Second")?.id == "second")
    }

    @Test func unknownFieldsAreIgnored() throws {
        let json = """
        [
          {
            "id":"swift",
            "name":"Swift",
            "aliases":["swift"],
            "category":"语言",
            "unexpected":{"nested":true},
            "parents":["x"]
          }
        ]
        """

        let dictionary = try skillDictionary(json)

        #expect(dictionary.skills.count == 1)
        #expect(dictionary.skill(named: "Swift")?.id == "swift")
    }

    @Test func malformedJSONFailsLoad() {
        #expect(throws: MatchingLexiconError.self) {
            _ = try skillDictionary("{not-json")
        }
    }

    @Test func canonicalNamesResolveCaseInsensitivelyWhileAliasesRemainScanOnly() throws {
        let dictionary = try skillDictionary(
            """
            [{"id":"swift","name":"Swift","aliases":["swift语言"],"category":"语言"}]
            """
        )

        #expect(dictionary.skill(named: "sWiFt")?.id == "swift")
        #expect(dictionary.skill(named: "swift语言") == nil)
        #expect(dictionary.skillID(forAlias: "Swift语言") == "swift")
    }

    @Test func englishAliasesRespectWordBoundariesAtTheDictionarySeam() {
        #expect(MatchingTextNormalizer.containsAlias("swift", in: "swift intern"))
        #expect(!MatchingTextNormalizer.containsAlias("swift", in: "swiftui intern"))
        #expect(MatchingTextNormalizer.containsAlias("oc", in: "熟悉 oc 语言"))
        #expect(!MatchingTextNormalizer.containsAlias("oc", in: "block chain"))
    }

    // MARK: - Role directions

    @Test func decodesRoleDirectionFamiliesWithNormalizedAliases() throws {
        let json = """
        [
          {"id":"ios","name":"iOS / Mobile","aliases":["iOS","移动端"],"extra":{"ignored":true}},
          {"id":"backend","name":"Backend","aliases":["backend","后端"]}
        ]
        """

        let lexicon = try MatchingLexiconLoader.makeRoleDirectionLexicon(from: Data(json.utf8))

        #expect(lexicon.directions.map(\.id) == ["ios", "backend"])
        #expect(lexicon.directions[0].aliases == ["ios", "移动端"])
        #expect(lexicon.directionID(forTargetRole: "iOS 开发实习") == "ios")
        #expect(lexicon.directionIDs(in: "Backend Intern").contains("backend"))
    }

    @Test func duplicateDirectionIDFailsLoad() {
        let json = """
        [
          {"id":"ios","name":"iOS","aliases":["ios"]},
          {"id":"ios","name":"Again","aliases":["ios2"]}
        ]
        """

        #expect(throws: MatchingLexiconError.duplicateID(resource: "RoleDirectionLexicon", id: "ios")) {
            _ = try MatchingLexiconLoader.makeRoleDirectionLexicon(from: Data(json.utf8))
        }
    }

    @Test(arguments: ["id", "name", "aliases"])
    func directionMissingRequiredFieldFailsLoad(_ field: String) throws {
        var record: [String: Any] = ["id": "ios", "name": "iOS", "aliases": ["ios"]]
        record.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: [record])

        #expect(throws: MatchingLexiconError.self) {
            _ = try MatchingLexiconLoader.makeRoleDirectionLexicon(from: data)
        }
    }

    @Test func crossDirectionDuplicateAliasKeepsTheFirstDictionaryEntry() throws {
        let json = """
        [
          {"id":"ios","name":"iOS","aliases":["mobile"]},
          {"id":"android","name":"Android","aliases":["mobile","android"]}
        ]
        """

        let lexicon = try MatchingLexiconLoader.makeRoleDirectionLexicon(from: Data(json.utf8))

        #expect(lexicon.directionID(forTargetRole: "Mobile 开发") == "ios")
    }

    // MARK: - Locations

    @Test func decodesLocationRegionsWithParentsAndAncestorRelations() throws {
        let json = """
        [
          {"id":"asia","name":"Asia","aliases":["asia","亚洲"]},
          {"id":"china","name":"China","aliases":["china","中国"],"parent":"asia"},
          {"id":"remote","name":"Remote","aliases":["remote","远程"]}
        ]
        """

        let lexicon = try MatchingLexiconLoader.makeLocationLexicon(from: Data(json.utf8))

        #expect(lexicon.regions.map(\.id) == ["asia", "china", "remote"])
        #expect(lexicon.region(id: "china")?.parentID == "asia")
        #expect(lexicon.regionIDs(in: "Shanghai, China") == ["china"])
        #expect(lexicon.related("asia", "china"))
        #expect(!lexicon.related("china", "remote"))
    }

    @Test func unknownLocationParentIsIgnoredInsteadOfFailingTheLoad() throws {
        let json = """
        [{"id":"atlantis","name":"Atlantis","aliases":["atlantis"],"parent":"missing"}]
        """

        let lexicon = try MatchingLexiconLoader.makeLocationLexicon(from: Data(json.utf8))

        #expect(lexicon.region(id: "atlantis")?.parentID == nil)
    }

    @Test func duplicateLocationIDFailsLoad() {
        let json = """
        [
          {"id":"china","name":"China","aliases":["china"]},
          {"id":"china","name":"Again","aliases":["中国"]}
        ]
        """

        #expect(throws: MatchingLexiconError.duplicateID(resource: "LocationLexicon", id: "china")) {
            _ = try MatchingLexiconLoader.makeLocationLexicon(from: Data(json.utf8))
        }
    }

    @Test(arguments: ["id", "name", "aliases"])
    func locationMissingRequiredFieldFailsLoad(_ field: String) throws {
        var record: [String: Any] = ["id": "china", "name": "China", "aliases": ["china"]]
        record.removeValue(forKey: field)
        let data = try JSONSerialization.data(withJSONObject: [record])

        #expect(throws: MatchingLexiconError.self) {
            _ = try MatchingLexiconLoader.makeLocationLexicon(from: data)
        }
    }

    // MARK: - Combined loading

    @Test func combinedLoaderReadsAllThreeInjectedURLs() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("NextStepLexiconTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let skillURL = directory.appendingPathComponent("skills.json")
        let directionURL = directory.appendingPathComponent("directions.json")
        let locationURL = directory.appendingPathComponent("locations.json")
        try Self.skillJSON.write(to: skillURL, atomically: true, encoding: .utf8)
        try Self.directionJSON.write(to: directionURL, atomically: true, encoding: .utf8)
        try Self.locationJSON.write(to: locationURL, atomically: true, encoding: .utf8)

        let loader = MatchingLexiconLoader(
            skillDictionaryURL: skillURL,
            roleDirectionURL: directionURL,
            locationURL: locationURL
        )
        let lexicon = try loader.load()

        #expect(lexicon.skillDictionary.skills.map(\.id) == ["swift", "swiftui", "combine"])
        #expect(lexicon.roleDirectionLexicon.direction(id: "ios") != nil)
        #expect(lexicon.locationLexicon.region(id: "china") != nil)
    }

    @Test func missingResourceFailsLoad() {
        let loader = MatchingLexiconLoader(
            skillDictionaryURL: nil,
            roleDirectionURL: nil,
            locationURL: nil
        )

        #expect(throws: MatchingLexiconError.missingResource("SkillDictionary")) {
            _ = try loader.load()
        }
    }

    @Test func unreadableResourceFailsLoad() {
        let missing = URL(fileURLWithPath: "/nonexistent/NextStep/skills.json")
        let loader = MatchingLexiconLoader(
            skillDictionaryURL: missing,
            roleDirectionURL: missing,
            locationURL: missing
        )

        #expect(throws: MatchingLexiconError.unreadableResource("SkillDictionary")) {
            _ = try loader.load()
        }
    }

    // MARK: - Bundled resources

    @Test func bundledLexiconsLoadFromTheAppBundle() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()

        #expect(lexicon.skillDictionary.skills.count == 65)
        let categories = Set(lexicon.skillDictionary.skills.map(\.category))
        #expect(
            categories.isSuperset(
                of: ["语言", "UI", "架构", "数据", "并发", "网络", "测试", "工具", "CS", "平台", "相邻"]
            )
        )

        let directionIDs = Set(lexicon.roleDirectionLexicon.directions.map(\.id))
        #expect(
            directionIDs.isSuperset(
                of: [
                    "ios", "android", "backend", "frontend", "data", "qa", "algorithm",
                    "product", "design", "devops", "security", "embedded", "game",
                ]
            )
        )

        let regionIDs = Set(lexicon.locationLexicon.regions.map(\.id))
        #expect(
            regionIDs.isSuperset(
                of: ["china", "asia", "europe", "us", "uk", "canada", "india", "japan", "singapore", "remote"]
            )
        )
    }

    @Test func everyBundledSkillCarriesChineseAndEnglishAliases() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()

        for skill in lexicon.skillDictionary.skills {
            let candidates = [skill.name] + skill.aliases
            #expect(candidates.contains(where: Self.containsCJK), "\(skill.id) needs a Chinese alias")
            #expect(
                candidates.contains(where: Self.containsASCIILetter),
                "\(skill.id) needs an English alias"
            )
        }
    }

    @Test func bundledSkillAliasesAvoidAmbiguousOneOrTwoLetterForms() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()
        let forbidden: Set<String> = ["go", "js", "os", "rn", "fp", "c"]

        for skill in lexicon.skillDictionary.skills {
            for alias in [skill.name] + skill.aliases {
                #expect(
                    !forbidden.contains(MatchingTextNormalizer.normalize(alias)),
                    "\(skill.id) contains ambiguous alias '\(alias)'"
                )
            }
        }
    }

    @Test func bundledSkillDictionaryContainsNoSoftSkills() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()
        let softSkillTerms = ["沟通", "团队协作", "学习能力", "软技能", "communication", "teamwork"]

        for skill in lexicon.skillDictionary.skills {
            for term in softSkillTerms {
                let candidates = [skill.name] + skill.aliases
                #expect(
                    !candidates.contains { $0.lowercased().contains(term) },
                    "\(skill.id) looks like a soft skill"
                )
            }
        }
    }

    @Test func bundledDictionariesAreAcyclicAndResolveKnownParents() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()

        #expect(lexicon.locationLexicon.related("asia", "china"))
        #expect(lexicon.locationLexicon.related("europe", "uk"))
        #expect(!lexicon.locationLexicon.related("us", "canada"))
        #expect(lexicon.locationLexicon.region(id: "remote")?.parentID == nil)
    }

    @Test func bundledDirectionAndLocationAliasesAreBilingual() throws {
        let lexicon = try MatchingLexiconLoader(bundle: .main).load()

        for direction in lexicon.roleDirectionLexicon.directions {
            let candidates = [direction.name] + direction.aliases
            #expect(
                candidates.contains(where: Self.containsCJK),
                "\(direction.id) needs a Chinese alias"
            )
            #expect(
                candidates.contains(where: Self.containsASCIILetter),
                "\(direction.id) needs an English alias"
            )
        }

        for region in lexicon.locationLexicon.regions {
            let candidates = [region.name] + region.aliases
            #expect(candidates.contains(where: Self.containsCJK), "\(region.id) needs a Chinese alias")
            #expect(
                candidates.contains(where: Self.containsASCIILetter),
                "\(region.id) needs an English alias"
            )
        }
    }

    // MARK: - Fixtures

    private static let skillJSON = """
    [
      {"id":"swift","name":"Swift","aliases":["swift","swift语言"],"category":"语言"},
      {"id":"swiftui","name":"SwiftUI","aliases":["swiftui","声明式ui"],"category":"UI"},
      {"id":"combine","name":"Combine","aliases":["combine","响应式编程"],"category":"并发"}
    ]
    """

    private static let directionJSON = """
    [
      {"id":"ios","name":"iOS / Mobile","aliases":["ios","mobile","移动端"]},
      {"id":"backend","name":"Backend","aliases":["backend","后端"]}
    ]
    """

    private static let locationJSON = """
    [
      {"id":"asia","name":"Asia","aliases":["asia","亚洲"]},
      {"id":"china","name":"China","aliases":["china","中国"],"parent":"asia"},
      {"id":"remote","name":"Remote","aliases":["remote","远程"]}
    ]
    """

    private static func containsCJK(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (0x3400...0x4DBF).contains(scalar.value) || (0x4E00...0x9FFF).contains(scalar.value)
        }
    }

    private static func containsASCIILetter(_ text: String) -> Bool {
        text.unicodeScalars.contains { scalar in
            (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
        }
    }
}
