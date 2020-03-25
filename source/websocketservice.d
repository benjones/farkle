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
    
    @path("/")
    void index(HTTPServerRequest req, HTTPServerResponse res){
        //        logInfo("redirecting to index.html");
        const roomList = getRoomList;
        res.render!("index.dt", roomList);
        //		redirect("/index.html");
    }

    @path("/farkle")
    void getFarkle(HTTPServerRequest req, HTTPServerResponse res){
        logInfo("farkle requested with query: %s", req.query);
        res.render!("farkle.dt");
    }
    
	@path("/ws") void getWebsocket(scope WebSocket socket){
        logInfo("ws connected");

        auto welcomeText = socket.receiveText();
        auto welcome = parseJson(welcomeText);

        logInfo("welcome message: %s", welcome);
        
        string roomName;
        Room room;
        if("roomName" in welcome){
            logInfo("roomname in welcome: %s", welcome["roomName"]);
        }
        if("roomName" in welcome && welcome["roomName"].length == 5){ //join room
            roomName = welcome["roomName"].get!string;
            room = getRoom(roomName);
        } else { //createRoom
            roomName = createRoomName();
            room = createRoom(roomName);
        }
        
        logInfo("joining room: %s", roomName);
        room.join(welcome["name"].get!string, socket);
        logInfo("joined");


        auto welcomeResponse = Json.emptyObject;
        welcomeResponse["type"] = "welcomeResponse";
        welcomeResponse["roomName"] = roomName;

        socket.send(welcomeResponse.toString);
        
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

    string createRoomName(){
        import std.random : uniform;

        char[5] name;
        foreach(ref c; name){
            c = cast(char)('a' + uniform(0, 26));
        }
        return name.dup;
        
    }
    
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
