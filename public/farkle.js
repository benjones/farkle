
const svgNS = "http://www.w3.org/2000/svg";

let ws; //global for debuggin purposes

const unheldBG = "red";
const heldBG = "blue";
const pipColor = "black";

window.onload = function(){

    ws = new WebSocket("ws://" + location.host + "/ws");
    ws.onmessage = handleMessage;

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
    if(gameState.lastScore.score == 0){
        let player = gameState.players[(gameState.whoseTurn - 1 + gameState.players.length)
                                       % gameState.players.length];
        farkleAlert.appendChild(document.createTextNode( player.name + " " +
                                                         gameState.lastScore.description + "'d"));
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
            
        } else {
            s.addEventListener("click", function(){
                let ret = {};
                ret.type = move;
                ws.send(JSON.stringify(ret));
            });
        }
    }
    
    
}

function handleMessage(message){
    let jo = JSON.parse(message.data);
    console.log(jo);
    if(jo.type == "gameState"){
        displayGameState(jo);
    } else if(jo.type == "yourTurn"){
        displayMoves(jo);
    }
}
