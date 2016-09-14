

// TODO: Check the use of distanceReferenceArray!!!!!

//TODO: Have a delay for the copying





import ddf.minim.*;
import ddf.minim.spi.*;
import ddf.minim.ugens.*;
import processing.serial.*;
import ddf.minim.analysis.*;


Minim  minim;
Worker worker;
Serial myPort;
AudioInput in;
AudioOutput out;
Sequencer sequencer;
AudioRecorder recorder;
ArrayList<Sampler> cubeSamples;
ArrayList<MultiChannelBuffer> sampleBuffer;

//---------------------------------------------------------------------

byte       cubeToRecord             =   0;
int       averageBpm                =   0;
int       recordingTime             =   0;
int       sleepTime                 =   0;
int       bufferLength              =   3;
int[]     triggerColors             =   {30,140,230,110,20,170};
int[]     cubes                     =   new int [8];
int[]     distanceArray             =   new int [8];
int[]     currentColorOf            =   new int [8];
int[]     currentSemitoneOf         =   new int [8];
float[]   currentSampleRateOf       =   new float [8];
int[]     distanceReferenceArray    =   new int [8];
int[]     semitones                 =   { -5, -2, 0, 2, 5, 7};
int       inByte                    =   0;
int       count                     =   0;
int       beat;

byte      lastTriggeredCube         =   0;
byte      hash                      =   35;
byte      frSlash                   =   47;
byte      bkSlash                   =   92;
byte      effect                    =   0;
byte      lBracket                  =   91;
byte      rBracket                  =   93;
byte      star                      =   42;
byte      exPr                      =   33;
byte      gtThan                    =   62;
byte      questionMark              =   63;
byte      dollar                    =   36;

float     volumeTreshold            =   60;
float     volumeMix                 =   0;

//Debugging
long      triggerStartTime          =   0;
long      triggerEndTime            =   0;

boolean   recording                 =   false;
boolean   ready                     =   false;
boolean   setupFinished             =   false;
boolean   boxIsTapped               =   false;
boolean   stopSequencer             =   false;
boolean   sequencerIsStopped        =   false;
boolean   isCopyingCubes            = false;
boolean[] cubesState                =   new boolean[8];


static final int    DEFAULTDISTANCEREFERENCE    = 300;
static final int    DEFAULTSAMPLERATE           = 44100;

//---------------------------------------------------------------------


void setup() {
    size(512, 200);
    for (int i = 0; i < Serial.list().length; ++i) {
        println("[" + i + "]" + Serial.list()[i]);
    }

    myPort  = new Serial(this, Serial.list()[0], 9600);
//    myPort.clear();
    myPort.bufferUntil('\n');  //Calls serialevent only when this character has arrived.
    minim   = new Minim(this);
    worker  = new Worker();
 

    //16 bit 44100khz sample buffer 512 stereo;
    in  = minim.getLineIn(Minim.STEREO, 1024);
    out = minim.getLineOut();

    cubeSamples   = new ArrayList<Sampler>();
    sampleBuffer  = new ArrayList<MultiChannelBuffer>();
    sequencer     = new Sequencer();

    for (int i = 0; i < cubes.length; i++) {
        cubes[i]  = i;
        sampleBuffer.add(new MultiChannelBuffer(4, 1024));
        float sampleRate = minim.loadFileIntoBuffer( i + ".wav", sampleBuffer.get(i) );
        cubeSamples.add(new Sampler(sampleBuffer.get(i), sampleRate, 4));
        cubeSamples.get(i).patch(out);
        println("Load test sample: " + cubes[i]);
    }

    recorder = minim.createRecorder(in, "bajs.wav", true);

    bpm = 130;
    beat = 0;

    // start the sequencer
    out.setTempo( bpm );
//    out.playNote( 0, 0.25f, sequencer );
    out.mute();
    textFont(createFont( "Arial", 12 ));
}

//---------------------------------------------------------------------

void draw() {
    if(!setupFinished){
      setupFinished = true;
    }
  
    if ( !ready ) {
//      println("waiting for heartbeat");
        return;
        ////For debugging
        // startAllBeats();
    }

    background(0);
    stroke(255);

    for ( int i = 0; i < in.left.size() - 1; i++ ) {
        line(i, 50 + in.left.get(i) * 50, i + 1, 50 + in.left.get(i + 1) * 50);
        line(i, 150 + in.right.get(i) * 50, i + 1, 150 + in.right.get(i + 1) * 50);
    }

    if ( recorder.isRecording() ) {
        text("Currently recording...", 5, 15);
    } else {
        text("Not recording.", 5, 15);
    }

    while ( recording ) {
        if (millis() - recordingTime >= 2000) {
            worker.endRecording();
        }
    }

    volumeMix = in.mix.level();
    volumeMix = int(volumeMix * 1000);

    if ( boxIsTapped ) {
        waitForVolumeTreshold();
    }

    if ( isCopyingCubes ) {
        if( worker.checkTimers(0) ){ 
            byte [] bytes = { hash, star, byte(worker.copyCubeNr1), byte(worker.copyCubeNr2) };
            sendSerial(bytes);
            isCopyingCubes = false;
        }
    }
}

//---------------------------------------------------------------------
//Wait for serial events
//---------------------------------------------------------------------

void serialEvent( Serial myPort ) {

//    println("SerialEvent triggered");

    while ( myPort.available() > 3 ) {
        inByte = myPort.read();
        ////For debug purpose
//       print("Time: "+ millis() + " - ReceivedByte: " + inByte);
//       println();
        boolean isReadyForMessage = setupFinished && inByte == hash;
        boolean isReadyForCommand = setupFinished && ready && inByte == hash;
        
        byte command; //set it to something we know we won't use
        if(isReadyForMessage){
            command = (byte) myPort.read();
            //text message
            if(command == 't' ){
              String message = myPort.readStringUntil('\n');
//              String message = "a";
              if(message.equals("a\n")){
                println("got handshake");
                setReadyAndShakeBack();
              }
              print("message received from Arduino: " + message);
              println();
            }
            
            if(isReadyForCommand){
              //copy cubes
              if ( command == star ) {
                  println("Copying Triggered");
                  stopStepSequencer();
                  worker.copyCubeNr1 = myPort.read();
                  worker.copyCubeNr2 = myPort.read();
                  print("copyCubeNr1: " + worker.copyCubeNr1 + " copyCubeNr2: " + worker.copyCubeNr2);
                  println();
                  worker.copyCubes(worker.copyCubeNr1, worker.copyCubeNr2);
                  isCopyingCubes = true;
                  worker.wait( 2000, 0 );
              }
  
              //recording cube
              if ( command == lBracket && !boxIsTapped ) {
                  println("Recording Triggered");
                  
                  cubeToRecord = (byte) myPort.read();
                  // lastTriggeredCube = (byte) cubeToRecord;
                  sleepTime = millis();
                  //TODO: A delay so that the recording isn't triggerred by the sound of tapping the cube.
                  // delay(400);// while(millis() - sleepTime < 2000){};
                  sleepTime = millis();
                   out.mute();
                  stopStepSequencer();
                  boxIsTapped = true;
              }
  
              //trigger cube
              if ( command == frSlash ) {
                  triggerStartTime = millis();
                  println("cube Triggered at:" + triggerStartTime);
                  int cube = myPort.read();
                  lastTriggeredCube = (byte)  cube;
                  int value = myPort.read();
                  startBeat(cube, value);
  
                  distanceArray[cube] = value;
                  setPitchShift( cube );
              }
  
              //trigger cube off
              if ( command == bkSlash ) {
                  println("cube turned off at:" + millis());
  
                  int cube = myPort.read();
                  stopBeat(cube);
                  currentSemitoneOf[cube] = -1000;// This is to make sure color is sent when triggering after cube is turned of.                
                  byte [] bytes = {hash, bkSlash, byte(cube)};
                  sendSerial(bytes);
              }
  
              //TODO: MessageType PitchColor == ?+colorByte
              if ( command == gtThan ) {
                  startStepSequencer();
              }
              
            }
            
            
        }
    }
}

void setReadyAndShakeBack(){
        println("Ready");
        byte [] bytes = {hash, 't', 'a'};
        sendSerial(bytes);
        ready = true;
        out.unmute();
        out.playNote( 0, 0.25f, sequencer );
}

void keyReleased(){
  if(key == 'a'){
    println("Recording Triggered");
    // lastTriggeredCube = (byte) cubeToRecord;
    sleepTime = millis();
    out.mute();
    stopStepSequencer();
    boxIsTapped = true;
  }
}

//---------------------------------------------------------------------
//wait for volume trigger
//---------------------------------------------------------------------

void waitForVolumeTreshold() {
    if ((millis() - sleepTime) <= 5000) {
        if (
        millis() - sleepTime > 400 //Wait a bit before listening. So that the sound od the tap itself doesn't trigger recording.
        && volumeMix >= volumeTreshold) {
            println("Treshold Reached:");
            boxIsTapped = false;
            byte [] bytes = {hash, lBracket, cubeToRecord};
            sendSerial(bytes);
            worker.startRecording();
        }
    } else {
        //send "recording timeout" to Arduino
        println("Timeout");
        byte [] bytes = { hash, exPr, cubeToRecord };
        sendSerial(bytes);
        boxIsTapped = false;
        startStepSequencer();
        out.unmute();
    }

}

//---------------------------------------------------------------------
//start a Beat
//---------------------------------------------------------------------

void startBeat( int cubeNumber, int value ) {
    if ( !cubesState[cubeNumber] ) {
        cubesState[cubeNumber] = true;
    }

    // distanceArray[cubeNumber] = value;
    // if ( cubesState[cubeNumber] ) {
        
    // }
}

//---------------------------------------------------------------------
//Start all beats
//---------------------------------------------------------------------

void startAllBeats() {
    for (int i = 0; i < cubes.length; i++) {
        cubesState[i] = true;
    }
}

//---------------------------------------------------------------------
//Stop a beat
//---------------------------------------------------------------------

void stopBeat( int cubeNumber ) {
    cubesState[cubeNumber] = false;
}

//---------------------------------------------------------------------
//Stop all beats
//---------------------------------------------------------------------

void stopAllBeats() {
    for (int i = 0; i < cubes.length; i++) {
        cubesState[i] = false;
    }
}

//---------------------------------------------------------------------
//Stop the sequencer
//---------------------------------------------------------------------

void stopStepSequencer() {
    stopSequencer = true;
}

//---------------------------------------------------------------------
//Start the sequencer
//---------------------------------------------------------------------

void startStepSequencer() {
    if ( sequencerIsStopped ) {
        sequencerIsStopped = false;
        out.playNote( 0, 0.25f, sequencer);
    }
    stopSequencer = false;
}


void setPitchShift( int cubeNumber ) {
    //int   scalePosition = (int) map (distanceArray[cubeNumber], 0, 255, 0, semitones.length);
    int   scalePosition = distanceArray[cubeNumber];
    // println("seeting scaleposiition for " + cubeNumber + " to " + scalePosition);
    int   semitone   = semitones[scalePosition];
    if (semitone == currentSemitoneOf[cubeNumber]) { //If we needn't change the pitch then exit this function
        return;
    }
    currentSemitoneOf[cubeNumber] = semitone;
    println("setting semitone of " + cubeNumber + " to " + semitone);
    float   noteHz      = exp( semitone * log(2) / 12 ) * ( DEFAULTSAMPLERATE );
    int   colorCube   = triggerColors[scalePosition];
    currentColorOf[cubeNumber] = colorCube;
    // int colorCube =0;
    // if(scalePosition % 2 == 0){
    //     colorCube = 0;
    // }else{
    //     colorCube = 128;
    // }
    // println("note: "+note);
    if (semitone == 0) {
//        cubeSamples.get(cubeNumber).setSampleRate(DEFAULTSAMPLERATE);
        currentSampleRateOf[cubeNumber] = DEFAULTSAMPLERATE;
        println("cube [ " + cubeNumber + " ]" + "new sampleRate: "  + DEFAULTSAMPLERATE);
    } else if (semitone != 0) {
//        cubeSamples.get(cubeNumber).setSampleRate(noteHz);
        currentSampleRateOf[cubeNumber] = noteHz;
        println("cube [ " + cubeNumber + " ] " + "new sampleRate: " + noteHz + "Hz");
    }

    byte [] bytes = {hash, questionMark, byte(cubeNumber), byte(colorCube)};
    sendSerial(bytes);
}


//---------------------------------------------------------------------
//Release and stop the recorder
//---------------------------------------------------------------------

void stop() {
    // always close Minim audio classes when you are done with them
    in.close();
    out.close();
    // always stop Minim before exiting
    minim.stop();
    super.stop();
}

//---------------------------------------------------------------------
//Send general serial messages
//---------------------------------------------------------------------

void sendSerial( byte[] bytes ) {
    String output = new String(bytes);
    println("sent the following to arduino: " + output);
    for (int i = 0; i < bytes.length; ++i) {
        myPort.write(bytes[i]);
    }
    myPort.write('\n');
}
