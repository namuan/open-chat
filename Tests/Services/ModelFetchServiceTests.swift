import XCTest
@testable import open_chat

final class ModelFetchServiceTests: XCTestCase {

    // MARK: - OpenRouter parsing

    func testParseOpenRouterFreeModelFromJSON() throws {
        let json = """
        {"data":[{"id":"meta-llama/llama-3.3-70b-instruct:free","name":"Meta:Llama","pricing":{"prompt":"0","completion":"0"}}]}
        """
        let info = parseOpenRouterJSON(json).first
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.free, true)
        XCTAssertEqual(info?.id, "meta-llama/llama-3.3-70b-instruct:free")
    }

    func testParseOpenRouterPaidModelFromJSON() throws {
        let json = """
        {"data":[{"id":"openai/gpt-4o","name":"OpenAI:GPT-4o","pricing":{"prompt":"0.000005","completion":"0.000015"}}]}
        """
        let model = parseOpenRouterJSON(json).first
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.free, false)
    }

    // MARK: - Requesty parsing

    func testParseRequestyFreeModelFromJSON() throws {
        let json = """
        {"data":[{"id":"google/gemma-4-31b-it","object":"model","input_price":0,"output_price":0}]}
        """
        let model = parseRequestyJSON(json).first
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.free, true)
    }

    func testParseRequestyPaidModelFromJSON() throws {
        let json = """
        {"data":[{"id":"openai/gpt-4o","object":"model","input_price":0.0000025,"output_price":0.00001}]}
        """
        let model = parseRequestyJSON(json).first
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.free, false)
    }

    func testParseRequestyIntZeroPrice() throws {
        let json = """
        {"data":[{"id":"free-int","input_price":0,"output_price":0}]}
        """
        let model = parseRequestyJSON(json).first
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.free, true)
    }

    // MARK: - Edge cases

    func testParseEmptyData() {
        XCTAssertEqual(parseOpenRouterJSON(#"{"data":[]}"#).count, 0)
        XCTAssertEqual(parseRequestyJSON(#"{"data":[]}"#).count, 0)
    }

    func testParseMissingPricingNotFree() {
        let json = #"{"data":[{"id":"no-pricing","name":"NoPricing"}]}"#
        let model = parseOpenRouterJSON(json).first
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.free, false)
    }

    func testParseMissingIDReturnsNil() {
        let json = #"{"data":[{"name":"NoID"}]}"#
        XCTAssertTrue(parseOpenRouterJSON(json).isEmpty)
    }

    func testParseMalformedJSONReturnsEmpty() {
        XCTAssertEqual(parseOpenRouterJSON("not json").count, 0)
        XCTAssertEqual(parseRequestyJSON("not json").count, 0)
    }

    // MARK: - ModelInfo equality

    func testModelInfoEquality() {
        let a = ModelFetchService.ModelInfo(id: "x", name: "X", free: true)
        let b = ModelFetchService.ModelInfo(id: "x", name: "X", free: true)
        let c = ModelFetchService.ModelInfo(id: "y", name: "Y", free: true)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    func testModelInfoDisplayName() {
        let free = ModelFetchService.ModelInfo(id: "x", name: "X", free: true)
        let paid = ModelFetchService.ModelInfo(id: "y", name: "Y", free: false)
        XCTAssertTrue(free.displayName.contains("free"))
        XCTAssertFalse(paid.displayName.contains("free"))
    }

    // MARK: - Parsing helpers (mirror actual logic)

    private func parseOpenRouterJSON(_ json: String) -> [ModelFetchService.ModelInfo] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["data"] as? [[String: Any]] else { return [] }
        return models.compactMap { model in
            guard let id = model["id"] as? String else { return nil }
            let name = model["name"] as? String ?? id
            let pricing = model["pricing"] as? [String: String]
            let promptCost = pricing?["prompt"] ?? "1"
            let completionCost = pricing?["completion"] ?? "1"
            let free = promptCost == "0" && completionCost == "0"
            return ModelFetchService.ModelInfo(id: id, name: name, free: free)
        }
    }

    private func parseRequestyJSON(_ json: String) -> [ModelFetchService.ModelInfo] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = obj["data"] as? [[String: Any]] else { return [] }
        return models.compactMap { model in
            guard let id = model["id"] as? String else { return nil }
            let name = model["id"] as? String ?? id
            let inputPrice  = (model["input_price"] as? NSNumber)?.doubleValue ?? -1
            let outputPrice = (model["output_price"] as? NSNumber)?.doubleValue ?? -1
            let free = inputPrice == 0.0 && outputPrice == 0.0
            return ModelFetchService.ModelInfo(id: id, name: name, free: free)
        }
    }
}