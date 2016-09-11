class Worker {

    private int wait;
    public int copyCubeNr1;
    public int copyCubeNr2;
    static final int NUMBEROFTIMERS = 6;

    private long [] waitTime    = new long[NUMBEROFTIMERS];
    private long [] currentTime = new long[NUMBEROFTIMERS];

// ------------------------------------------------------------------------------------

    Worker () {
        copyCubeNr1         = 0;
        copyCubeNr2         = 1;
        wait( 2000, 0 );
    }


// ------------------------------------------------------------------------------------

    private void sleep( long  sleepTime ) {
        try {
            sleep(sleepTime);
        } catch ( Exception e ) {
        }

    }


    public void refreshSampleBuffer(int cubeNumber) {

        minim.loadFileIntoBuffer(cubeNumber + ".wav", sampleBuffer.get(cubeNumber));
        cubeSamples.get(cubeNumber).setSample(sampleBuffer.get(cubeNumber), DEFAULTSAMPLERATE);//cubeSamples.get(cubeNumber).sampleRate());

    }

//---------------------------------------------------------------------
//copy .wav
//---------------------------------------------------------------------

    public void copyCubes( int cubeNumber1, int cubeNumber2 ) {
        //out.mute();
        stopStepSequencer();
        println("Try to copy from" + cubeNumber1 + "to" + cubeNumber2);

        byte [] b = loadBytes( cubeNumber1 + ".wav");
        saveBytes(cubeNumber2 + ".wav", b);
        refreshSampleBuffer(cubeNumber2);



    }

//---------------------------------------------------------------------
//start recording sound
//---------------------------------------------------------------------

    public void startRecording() {
        // if ( cubesState[cubeToRecord] ) {
        //     distanceReferenceArray[cubeToRecord] = distanceArray[cubeToRecord];
        // } else {
        //     distanceReferenceArray[cubeToRecord] = DEFAULTDISTANCEREFERENCE;
        // }

        recorder = minim.createRecorder(in, cubes[cubeToRecord] + ".wav", true);
        recordingTime = millis();
        println("Recording! Psst!! -- Next Volume:");
        recorder.beginRecord();
        recording = true;
        recordingTime = millis();
    }

//---------------------------------------------------------------------

    void endRecording() {
        recorder.endRecord();
        println("Done recording.");
        recorder.save();
        println("Done saving.");
        recording = false;
        refreshSampleBuffer(cubeToRecord);
        byte [] bytes = {hash, rBracket, cubeToRecord};
        sendSerial(bytes);
        startStepSequencer();
        myPort.clear();
        out.unmute();

    }

//---------------------------------------------------------------------

    //set up to 6 Timers:
    void wait( int _waitTime, int _numberOfIndex ) {
        waitTime[_numberOfIndex] = _waitTime;
        currentTime[_numberOfIndex] = millis();
    }

//---------------------------------------------------------------------

    //check Time:
    boolean checkTimers( int _index ) {
        boolean isTimePassed = millis() - currentTime[_index] >= waitTime[_index];
        if ( isTimePassed ) {
            currentTime[_index] = millis();
            return true;
        } else {
            return false;
        }
    }

}