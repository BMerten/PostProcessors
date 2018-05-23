/**

  Postprocessor for MG Corta P 2500 with Plasma-Torch
  Hypertherm Powermaxx45
  
  V 0.9 16.02.2018 B. Merten
  
*/

description = "Corta P 2500";
vendor = "Messer Griesheim";
legal = "written by B. Merten 2018";
certificationLevel = 2;
minimumRevision = 39000;

longDescription = "Plasma Cutting";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined; // allow any circular motion

separateWordsWithSpace = true; // specifies that the words should be separated with a white space
sequenceNumberStart = 1; // first sequence number
showSequenceNumbers = true; // show sequence numbers
sequenceNumberIncrement = 1; // increment for sequence numbers
writeMachine = true; // write machine
allowHeadSwitches = false; // output code to allow heads to be manually switched for piercing and cutting
w_plane = 0; // Werkzeugarbeitsebene

// user-defined properties
properties = {
  retract: 0, // Rueckzugshoehe Eilgang
};

// user-defined property definitions
propertyDefinitions = {
  retract: {title:"Rueckzugshoehe", description:"Rueckzugshoehe Eilgang", type:"integer"}
};

// ************************************************************************************************************************************************************
// Definition der Ausgabeformate und Ausgabevariablen
// ************************************************************************************************************************************************************


var gFormat = createFormat({prefix:"G", zeropad:true, width:2, decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});
var dFormat = createFormat({prefix:"D", decimals:0}); 
var fFormat = createFormat({prefix:"F", decimals:0}); // kerf index
var nFormat = createFormat({decimals:0, zeropad:true, width:4});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var toolFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-1000

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var zOutput = createVariable({prefix:"Z"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);

var iOutput = createReferenceVariable({prefix:"I"}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J"}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21

var WARNING_WORK_OFFSET = 0;

// ************************************************************************************************************************************************************
// Initialisierung der allgemeinen Parameter // Programmbeginn
// ************************************************************************************************************************************************************

function onOpen() {
  
// ** Leerzeichen einfuegen  
  
    if (!separateWordsWithSpace) {
        setWordSeparator("");
    }

// ** Satznummern bei 1 starten

    sequenceNumber = sequenceNumberStart;

// ** Programmnamen schreiben

    if (programName) {
        writeComment(programName);
        writeln("");
    }
  
// ** Programmkommentar schreiben
  
    if (programComment) {
        writeComment(programComment);
        writeln("");
    }

// ** Verfahrwege nach absoluten Koordinaten
  
    writeComment("Absolute Koordinaten");
    writeBlock(gAbsIncModal.format(90));

// ** Masseinheiten im mm

    writeComment("Werte in mm");
    writeBlock(gUnitModal.format(21));
  
}
  
// ************************************************************************************************************************************************************
// Programmende
// ************************************************************************************************************************************************************

function onClose() {
  writeln("");
  
  writeComment("Ursprung anfahren");
  writeBlock(gMotionModal.format(0), xOutput.format(0), yOutput.format(0));
  
  writeln("");
  onImpliedCommand(COMMAND_END);
  writeComment("Programmende");
  writeBlock(mFormat.format(30));
}

// ************************************************************************************************************************************************************
// Beginn eines neuen Abschnitts
// ************************************************************************************************************************************************************

function onSection() {
//var z = zOutput.format(-properties.retract);

  var insertToolCall = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());

  writeln("");

  if (hasParameter("operation-comment")) {
   var comment = getParameter("operation-comment");
  if (comment) {
    writeComment(comment);
   }
  }

      writeComment("Plasma-Schneiden");
      writeBlock(mFormat.format(36), "T" + toolFormat.format(1));
      writeComment("Rueckzugshoehe anfahren");
      writeBlock(gMotionModal.format(0), xOutput.format(0), yOutput.format(0), zOutput.format(-properties.retract));
      
    
      writeln("");

  forceXYZ();

  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());

  if (insertToolCall || retracted) {
    gMotionModal.reset();

    if (!machineConfiguration.isHeadConfiguration()) {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0), 
        xOutput.format(initialPosition.x), 
        yOutput.format(initialPosition.y)
      );
      writeln("");
    } else {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0),
        xOutput.format(initialPosition.x),
        yOutput.format(initialPosition.y)
      );
      writeln("");
    }
  } else {
    writeBlock(
      gAbsIncModal.format(90),
      gMotionModal.format(0),
      xOutput.format(initialPosition.x),
      yOutput.format(initialPosition.y)
    );
    writeln("");
  }
}

// ************************************************************************************************************************************************************
// Ende eines Abschnitts
// ************************************************************************************************************************************************************

function onSectionEnd() {
  setDeviceMode(false);
  forceAny();
}

// ************************************************************************************************************************************************************
// Verfahrbefehle im Eilgang (G00)
// ************************************************************************************************************************************************************

function onRapid(_x, _y, _z) {
gMotionModal.reset();
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    writeBlock(gMotionModal.format(0), x, y);
    writeln("");
    feedOutput.reset();
  }
}

// ************************************************************************************************************************************************************
// Lineare Verfahrbefehle (G01)
// ************************************************************************************************************************************************************

function onLinear(_x, _y, _z, feed) {
    gMotionModal.reset();
  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var f = feedOutput.format(feed);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
    switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gFormat.format(41));
        // use dFormat for keft offset - which is currently not supported
        writeBlock(gMotionModal.format(1), x, y, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gFormat.format(42));
        // use dFormat for keft offset - which is currently not supported
        writeBlock(gMotionModal.format(1), x, y, f);
        break;
      default:
        writeBlock(gFormat.format(40));
        writeBlock(gMotionModal.format(1), x, y, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

// ************************************************************************************************************************************************************
// Zirkulare Verfahrbefehle (G02,G03)
// ************************************************************************************************************************************************************

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {

  // one of X/Y and I/J are required and likewise
  
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();
  if (isFullCircle()) {
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}


// ************************************************************************************************************************************************************
// 
// ************************************************************************************************************************************************************

function onComment(message) {
  writeComment(message);
}

// ************************************************************************************************************************************************************
// Erzwingung der Ausgabe von Wiederholungsbefehlen
// ************************************************************************************************************************************************************

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}


// ************************************************************************************************************************************************************
// Zeilenausgabe der Steuerungsbefehle
// ************************************************************************************************************************************************************

var sequenceNumber;
var currentWorkOffset;

function writeBlock() {
  if (showSequenceNumbers) {
    writeWords2("N" + nFormat.format(sequenceNumber), arguments);
    sequenceNumber += sequenceNumberIncrement;
  } else {
    writeWords(arguments);
  }
}

// ************************************************************************************************************************************************************
// Zeilenausgabe von Kommentaren
// ************************************************************************************************************************************************************

function formatComment(text) {
  return "(" + String(text).replace(/[\(\)]/g, "") + ")";
}

function writeComment(text) {
  writeln(formatComment(text));
}

// ************************************************************************************************************************************************************
// Radiuskompensierung
// ************************************************************************************************************************************************************


var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var shapeArea = 0;
var shapePerimeter = 0;
var shapeSide = "inner";
var cuttingSequence = "";


// ************************************************************************************************************************************************************
// 
// ************************************************************************************************************************************************************

function onParameter(name, value) {
  if ((name == "action") && (value == "pierce")) {
  } else if (name == "shapeArea") {
    shapeArea = value;
  } else if (name == "shapePerimeter") {
    shapePerimeter = value;
  } else if (name == "shapeSide") {
    shapeSide = value;
  } else if (name == "beginSequence") {
    if (value == "piercing") {
      if (cuttingSequence != "piercing") {
        if (allowHeadSwitches) {
          writeln("");
          writeComment("Switch to piercing head before continuing");
          onCommand(COMMAND_STOP);
          writeln("");
        }
      }
    } else if (value == "cutting") {
      if (cuttingSequence == "piercing") {
        if (allowHeadSwitches) {
          writeln("");
          writeComment("Switch to cutting head before continuing");
          onCommand(COMMAND_STOP);
          writeln("");
        }
      }
    }
    cuttingSequence = value;
  }
}

// ************************************************************************************************************************************************************
// Schalten der Werkzeugmaschinen
// ************************************************************************************************************************************************************

function onPower(power) {
  setDeviceMode(power);
}

var deviceOn = false;

function setDeviceMode(enable) {
  if (enable != deviceOn) {
    deviceOn = enable;
    if (enable) {
      // to working plane
        writeComment("Arbeitshoehe anfahren");
        writeBlock(gMotionModal.format(0), zOutput.format(w_plane));
        writeComment("Lichtbogen ein");
        writeBlock(mFormat.format(70));
        writeComment("Achsfreigabe");
        writeBlock(mFormat.format(16), fFormat.format(163)); // wait
        
        writeln("");
    
    } else {
      //to retract plane
        writeln("");
        writeComment("Lichtbogen aus");
        writeBlock(mFormat.format(-70));
        writeComment("Rueckzugshoehe anfahren");
        writeBlock(gMotionModal.format(0), zOutput.format(-properties.retract));
        
        writeln("");
      }
    }
  }


