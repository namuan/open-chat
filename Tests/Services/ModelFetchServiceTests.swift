import XCTest
@testable import open_chat

final class ModelFetchServiceTests: XCTestCase {

    // MARK: - OpenRouter JSON parsing

    func testParseOpenRouterFreeModel() {
        let json = """
        {
          "data": [
            {
              "id": "meta-llama/llama-3.3-70b-instruct:free",
              "name": "Meta: Llama 3.3 70B Instruct (free)",
              "pricing": {
                "prompt": "0",
                "completion": "0"
              }
            }
          ]
        }
        """

        let models = parseOpenRouterJSON(json)
        XCTAssertEqual(models.count, 1)
        XCTAssertTrue(models[0].free)
        XCTAssertEqual(models[0].id, "meta-llama/llama-3.3-70b-instruct:free")
        XCTAssertEqual(models[0].name, "Meta: Llama 3.3 70B Instruct (free)")
    }

    func testParseOpenRouterPaidModel() {
        let json = """
        {
          "data": [
            {
              "id": "openai/gpt-4o",
              "name": "OpenAI: GPT-4o",
              "pricing": {
                "prompt": "0.000005",
                "completion": "0.000015"
              }
            }
          ]
        }
        """

        let models = parseOpenRouterJSON(json)
        XCTAssertEqual(models.count, 1)
        XCTAssertFalse(models[0].free)
    }

    // MARK: - Requesty JSON parsing

    func testParseRequestyFreeModel() {
        let json = """
        {
          "data": [
            {
              "id": "google/gemma-4-31b-it",
              "object": "model",
              "input_price": 0,
              "output_price": 0
            }
          ]
        }
        """

        let models = parseRequestyJSON(json)
        XCTAssertEqual(models.count, 1)
        XCTAssertTrue(models[0].free)
    }

    func testParseRequestyPaidModel() {
        let json = """
        {
          "data": [
            {
              "id": "openai/gpt-4o",
              "object": "model",
              "input_price": 0.0000025,
              "output_price": 0.00001
            }
          ]
        }
        """

        let models = parseRequestyJSON(json)
        XCTAssertEqual(models.count, 1)
        XCTAssertFalse(models[0].free)
    }

    // MARK: - Edge cases

    func testParseEmptyResponse() {
        XCTAssertEqual(parseOpenRouterJSON(#"{"data": []}"#).count, 0)
        XCTAssertEqual(parseRequestyJSON(#"{"data": []}"#).count, 0)
    }

    func testParseMissingPricing() {
        let json = """
        {
          "data": [{"id": "no-pricing", "name": "No Pricing"}]
        }
        """
        let models = parseOpenRouterJSON(json)
        XCTAssertEqual(models.count, 1)
        // Missing pricing should NOT be treated as free
        XCTAssertFalse(models[0].free)
    }

    // MARK: - Helpers (mimic the actual parsing logic)

    private func parseOpenRouterJSON(_ json: String) -> [ModelFetchService.ModelInfo] {
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let models = obj["data"] as! [[String: Any]]

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
        let data = json.data(using: .utf8)!
        let obj = try! JSONSerialization.jsonObject(with: data) as! [String: Any]
        let models = obj["data"] as! [[String: Any]]

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
