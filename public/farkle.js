
const svgNS = "http://www.w3.org/2000/svg";

let ws; //global for debuggin purposes

const unheldBG = "red";
const heldBG = "blue";
const pipColor = "black";

let roomName;
let userName;

window.onload = function(){


    const urlParams = new URLSearchParams(window.location.search);
    userName = urlParams.get("name");
    roomName = urlParams.get("roomName");
    console.log(userName);
    console.log(roomName);
    if(!userName){
        console.log("username is falsy, redirecting");
        console.log(location.host + "/");
        window.location = "/";
        return;
    }

    ws = new WebSocket("ws://" + location.host + "/ws");
    ws.onmessage = handleMessage;

    
    let welcome = {name : userName};
    if(roomName){
        welcome.roomName = roomName;
    }

    ws.onopen = function(){
        ws.send(JSON.stringify(welcome));

        window.setInterval(function(){
            let ping = {type : "ping"};
            ws.send(JSON.stringify(ping));
        }, 15000);
    }
    
    let dice = document.getElementsByClassName("die");
    for(let i = 0; i < dice.length; i++){
        initDie(dice[i]);
        updateDie(dice[i], i +1);
    }

    
}



function initDie(die){

    let svgRect = die.getBoundingClientRect();

    let bg = document.createElementNS(svgNS, "rect");
    bg.setAttribute("width", svgRect.width);
    bg.setAttribute("height", svgRect.height);
    bg.setAttribute("rx", svgRect.width*.1);

    die.appendChild(bg);
}


function updateDie(die, showing){

    const allPips = [
        [ [0.5, 0.5] ],
        [ [0.25, 0.25], [0.75, 0.75]],
        [ [0.25, 0.25], [0.5, 0.5], [0.75, 0.75] ],
        [ [0.25, 0.25], [0.25, 0.75], [0.75, 0.25], [0.75, 0.75] ],
        [ [0.25, 0.25], [0.25, 0.75], [0.75, 0.25], [0.75, 0.75], [0.5, 0.5] ],
        [ [0.25, 0.25], [0.25, 0.5], [0.25, 0.75], [0.75, 0.25], [0.75, 0.5], [0.75, 0.75] ],
    ];

    //delete old pips

    let oldPips = die.querySelectorAll(".pip");
    for(let pip of oldPips){
        pip.remove();
    }

    if(showing < 1 || showing > 6) return;
    
    for( let coord of allPips[showing -1]){
        let svgRect = die.getBoundingClientRect();
        let sw = svgRect.width;
        let sh = svgRect.height;
        
        let pip = document.createElementNS(svgNS, "circle");
        pip.setAttribute("cx", coord[0]*sw);
        pip.setAttribute("cy", coord[1]*sh);
        pip.setAttribute("r", 0.08*sw);
        pip.setAttribute("fill", pipColor);
        pip.setAttribute("class", "pip");
        
        die.appendChild(pip);
    }
}

function setHeld(die, isHeld){
    let bg = die.getElementsByTagName("rect")[0];
    bg.classList.remove("pendingHold");
    if(isHeld){
        bg.classList.add("held");
    } else {
        bg.classList.remove("held");
    }
}

function displayGameState(gameState){
    let dice = document.getElementsByClassName("die");
    for(let i = 0; i < gameState.dice.length; i++){
        updateDie(dice[i], gameState.dice[i].showing);
        setHeld(dice[i], gameState.dice[i].held);
    }
    
    let tbody = document.getElementById("scoreArea");
    tbody.innerHTML = "";
    for(let player of gameState.players){
        let tr = document.createElement("tr");
        let nameField = document.createElement("td");
        nameField.appendChild(document.createTextNode(player.name));
        let scoreField = document.createElement("td");
        scoreField.appendChild(document.createTextNode(player.score));
        tr.appendChild(nameField);
        tr.appendChild(scoreField);
        
        tbody.appendChild(tr);
    }
    tbody.getElementsByTagName("tr")[gameState.whoseTurn].classList.add("activePlayer");

    let scoreBody = document.getElementById("scoresThisTurn");
    scoreBody.innerHTML = "";
    for(let scoringDie of gameState.scoringMoves){
        let tr = document.createElement("tr");
        //score diceUsed description
        let scoreField = document.createElement("td");
        scoreField.appendChild(document.createTextNode(scoringDie.score));
        let descriptionField = document.createElement("td");
        descriptionField.appendChild(document.createTextNode(scoringDie.description));
        let diceUsedField = document.createElement("td");
        diceUsedField.appendChild(document.createTextNode(scoringDie.diceUsed));

        tr.appendChild(scoreField);
        tr.appendChild(descriptionField);
        tr.appendChild(diceUsedField);
        
        scoreBody.appendChild(tr);
        
    }

    let farkleAlert = document.getElementById("farkleAlert");
    farkleAlert.innerHTML = "";
    if(gameState.showingScore.score == 0){
        let player = gameState.players[(gameState.whoseTurn - 1 + gameState.players.length)
                                       % gameState.players.length];
        farkleAlert.appendChild(document.createTextNode( player.name + " " +
                                                         gameState.lastScore.description + "'d"));
    }

    let showingScore = document.getElementById("showingScore");
    showingScore.innerHTML = "";
    if(gameState.showingScore.score > 0){
        showingScore.appendChild(document.createTextNode("Score showing: " +
                                                         gameState.showingScore.description +
                                                         " worth " +
                                                         gameState.showingScore.score));
    }
    
}

function diceHandler(){
    console.log("dice handler");
    console.log(this);
    this.getElementsByTagName("rect")[0].classList.toggle("pendingHold");
}

function clearDiceHandlers(){
    let dice = document.getElementsByClassName("die");
    for(let die of dice){
        die.removeEventListener("click", diceHandler);
    }
}

function sendMessage(){
    let chatBox = document.getElementById("chatBox");
    let mess = { type : "chat", user : userName, message : chatBox.value };
    ws.send(JSON.stringify(mess));
    chatBox.value = "";
    return false;
}

function addDiceHandlers(){
    let dice = document.getElementsByClassName("die");
    for(let die of dice){
        let rect = die.getElementsByTagName("rect")[0];
        if(!rect.classList.contains("held")){
            die.addEventListener("click", diceHandler);
        }
    }
}

function displayMoves(message){

    clearDiceHandlers();
    let movDiv = document.getElementById("moves");
    movDiv.innerHTML = "";
    
    for(let move of message.legalMoves){
        let s = document.createElement("span");
        s.classList.add("moveButton");
        s.appendChild(document.createTextNode(move));
        movDiv.appendChild(s);
        s.addEventListener("click", function(){
            clearDiceHandlers();
            movDiv.innerHTML = ""; //clear this after we move
        });
        
        if(move == "Roll" || move =="Stay"){
            addDiceHandlers();

            s.addEventListener("click", function(){
                //collect the newly pending dice
                let ret = {};
                ret.type = move;
                let holds = [];
                
                let dice = document.getElementsByClassName("die");
                for(let i = 0; i < dice.length; i++){
                    let die = dice[i];
                    let rect = die.getElementsByTagName("rect")[0];
                    if(rect.classList.contains("pendingHold")){
                        holds.push(i);
                        rect.classList.remove("pendingHold");
                    }
                }
                if(move == "Roll"){
                    ret.newHolds = holds;
                } else {
                    ret.toHold = holds;
                }
                ws.send(JSON.stringify(ret));
            });
            
        } else { //Steal or NewRoll
            s.addEventListener("click", function(){
                let ret = {};
                ret.type = move;
                ws.send(JSON.stringify(ret));
            });
        }
    }
    
    
}

function displayChatMessage(message){

    let chatDiv = document.getElementById("chatMessages");
    let nd = document.createElement("div");
    nd.appendChild(document.createTextNode(message.user + ": " + message.message));
    chatDiv.appendChild(nd);
    
}

function handleMessage(message){
    let jo = JSON.parse(message.data);
    console.log(jo);
    if(jo.type == "pong"){
        return;
    } else if(jo.type == "welcomeResponse"){
        document.getElementById("roomName").innerHTML =
            userName + " playing in room " + jo.roomName;
    } else if(jo.type == "gameState"){
        displayGameState(jo);
    } else if(jo.type == "yourTurn"){
        displayMoves(jo);
    } else if(jo.type == "chat"){
        displayChatMessage(jo);
    }
}
