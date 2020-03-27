module room;

import farkle;
import vibe.core.sync : LocalManualEvent, createManualEvent;
import vibe.http.websockets : WebSocket;
import vibe.data.json;
import vibe.core.log;

struct LogEntry {
    Player player;
    Move move;
}

class Room {
    
    Farkle farkle;
    LogEntry[] log;

    ulong numPlayers(){
        return farkle.numPlayers;
    }

    bool empty(){
        return numPlayers == 0;
    }
    
    void join(string name, WebSocket socket){
        farkle.addPlayer(Player(name, 0, socket));
        if(farkle.isMyTurn(socket)){
            farkle.messageActivePlayer(farkle.legalMoves);
        }
    }

    bool leave(WebSocket socket){
        return farkle.removePlayer(socket);
    }

    bool isMyTurn(WebSocket socket){
        return farkle.isMyTurn(socket);
    }
    
    void takeTurn(WebSocket ws, Json command){
        import std.algorithm : map;
        import std.array;
        
        auto player = farkle.getPlayer(ws);
        logInfo("player %s taking turn with command: %s", player, command);
        Move move;
        auto type = command["type"];
        if(type.type != Json.Type.string){
            logInfo("no type!");
            assert(false);
        }

        auto ts = type.get!string;

        if(ts == "Roll"){
            auto newHoldsJson = command["newHolds"];
            if(newHoldsJson.type != Json.Type.array){
                logInfo("no newHolds");
                assert(false);
            }
            auto newHolds = newHoldsJson.get!(Json[]).map!(a => a.get!int).array;
            move = Roll(newHolds);
        } else if(ts == "Stay"){
            auto toHoldJson = command["toHold"];
            if(toHoldJson.type != Json.Type.array){
                logInfo("no toHolds");
                assert(false);
            }
            auto toHold = toHoldJson.get!(Json[]).map!(a => a.get!int).array;
            move = Stay(toHold);
        } else if(ts == "NewRoll"){
            move = NewRoll();
        } else if(ts == "Steal"){
            move = Steal();
        } else {
            logInfo("unknown command type");
            assert(false);
        }
        logInfo("turn: %s", command);
        if(farkle.isLegalMove(move)){
            farkle.takeAction(move);
        }

        farkle.sendUpdatesToPlayers();
        
    }

}

