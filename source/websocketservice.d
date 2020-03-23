module websocketservice;

import room;
import vibe.web.common : path;
import vibe.http.websockets : WebSocket;
import vibe.web.web : redirect;
import vibe.core.log;
import vibe.core.core : runTask;
import vibe.data.json;


class WebsocketService {
    @path("/") void getHome()
	{
        logInfo("redirecting to index.html");
		redirect("/index.html");
    }

	@path("/ws") void getWebsocket(scope WebSocket socket){
        logInfo("ws connected");
        auto room = getRoom();
        logInfo("joining room");
        room.join("name", socket);
        logInfo("joined");

		while (socket.waitForData) {
            auto message = socket.receiveText();
            auto jo = parseJson(message);
            if(room.isMyTurn(socket)){
                room.takeTurn(socket,jo);
            }
		}
        logInfo("leaving room");
        room.leave(socket);
		logInfo("Client disconnected.");
	}
}
