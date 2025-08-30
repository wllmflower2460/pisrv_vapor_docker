import Vapor

struct MockClient: Client {
    let eventLoopGroup: EventLoopGroup
    var eventLoop: EventLoop { eventLoopGroup.next() }

    func send(_ request: ClientRequest) -> EventLoopFuture<ClientResponse> {
        let json = #"{"latent":[0.1,0.2],"motif_scores":[0.3,0.4,0.5]}"#
        var headers = HTTPHeaders()
        headers.add(name: .contentType, value: "application/json")
        let body = ByteBuffer(string: json)
        let resp = ClientResponse(status: .ok, headers: headers, body: body)
        return eventLoop.makeSucceededFuture(resp)
    }

    // Updated to match current Vapor Client protocol signature
    func delegating(to eventLoop: EventLoop) -> Client { self }
    func shutdown() {}
}
