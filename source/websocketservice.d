module websocketservice;

import room;
import vibe.web.common : path;
import vibe.http.websockets : WebSocket;
import vibe.http.server : render, HTTPServerRequest, HTTPServerResponse;
import vibe.web.web : redirect;
import vibe.core.log;
import vibe.core.core : runTask;
import vibe.data.json;


class WebsocketService {

    private Room[string] roomIndex;
    
    @path("/") void index(HTTPServerRequest req, HTTPServerResponse res)
	{
        //        logInfo("redirecting to index.html");
        const roomList = getRoomList;
        res.render!("index.dt", roomList);
        //		redirect("/index.html");
    }

	@path("/ws") void getWebsocket(scope WebSocket socket){
        logInfo("ws connected");
        auto room = createRoom("room");
        if(room is null)
            room = getRoom("room");
        
        logInfo("joining room");
        room.join("name", socket);
        logInfo("joined");

		while (socket.waitForData) {
            auto message = socket.receiveText();
            logInfo("message: %s", message);
            auto jo = parseJson(message);
            logInfo("JSON message: %s", jo);
            if(room.isMyTurn(socket)){
                logInfo("taking my turn");
                room.takeTurn(socket,jo);
            }
		}
        logInfo("leaving room");
        room.leave(socket);
		logInfo("Client disconnected.");
	}



private:
    Room createRoom(string name){
        if(name in roomIndex){
            return null;
        }
        logInfo("making new room: %s", name);
        Room r = new Room();
        roomIndex[name] = r;
        return r;
    }
    
    Room getRoom(string name){

        if(name !in roomIndex){
            return null;
        }
        logInfo("getting room: ", name);
        return roomIndex[name];

    }

    string[] getRoomList(){
        return roomIndex.keys;
    }

    
}
