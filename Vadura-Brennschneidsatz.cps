/**
  Postprocessor for MG Corta P 2500 with Oxyfuel Cutting
  Vadura-Nozzles
  
  V 0.9 16.02.2018 B. Merten
  
*/

description = "Corta P 2500";
vendor = "Messer Griesheim";
legal = "written by B. Merten 2018";
certificationLevel = 2;
minimumRevision = 39000;

longDescription = "Oxyfuel Cutting";

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




// user-defined properties
properties = {
  writeMachine: true, // write machine
  showSequenceNumbers: true, // show sequence numbers
  sequenceNumberStart: 1, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  allowHeadSwitches: false, // output code to allow heads to be manually switched for piercing and cutting
  separateWordsWithSpace: true // specifies that the words should be separated with a white space
};

// user-defined property definitions
propertyDefinitions = {
  writeMachine: {title:"Write machine", description:"Output the machine settings in the header of the code.", group:0, type:"boolean"},
  showSequenceNumbers: {title:"Use sequence numbers", description:"Use sequence numbers for each block of outputted code.", group:1, type:"boolean"},
  sequenceNumberStart: {title:"Start sequence number", description:"The number at which to start the sequence numbers.", group:1, type:"integer"},
  sequenceNumberIncrement: {title:"Sequence number increment", description:"The amount by which the sequence number is incremented by in each block.", group:1, type:"integer"},
  allowHeadSwitches: {title:"Allow head switches", description:"Enable to output code to allow heads to be manually switched for piercing and cutting.", type:"boolean"},
  separateWordsWithSpace: {title:"Separate words with space", description:"Adds spaces between words if 'yes' is selected.", type:"boolean"}
};


// ************************************************************************************************************************************************************
// Definition der Ausgabeformate und Ausgabevariablen
// ************************************************************************************************************************************************************


var gFormat = createFormat({prefix:"G", zeropad:true, width:2, decimals:0});
var mFormat = createFormat({prefix:"M", zeropad:true, width:2, decimals:0});
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
  
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

  if (properties.writeMachine && (vendor || model || description)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (description) {
      writeComment("  " + localize("description") + ": "  + description);
    }
  }

  // absolute coordinates and feed per min
  writeComment("Absolute Koordinaten");
  writeBlock(gAbsIncModal.format(90));
  
  switch (unit) {
  case IN:
    writeComment("Werte in inch");
    writeBlock(gUnitModal.format(20));
    break;
  case MM:
    writeComment("Werte in mm");
    writeBlock(gUnitModal.format(21));
    break;
  }
}

// ************************************************************************************************************************************************************
// Programmende
// ************************************************************************************************************************************************************

function onClose() {
  forceAny();
  
  //onCommand(COMMAND_COOLANT_OFF);

  //writeBlock(mFormat.format(19));
  //writeBlock(gFormat.format(280), gFormat.format(281));
  
  writeComment("Ursprung anfahren");
  writeBlock(gMotionModal.format(0), xOutput.format(0), yOutput.format(0));
  
  writeln("");
  
  writeComment("Heizflamme loeschen");
  writeBlock(mFormat.format(-71));
  writeBlock(gFormat.format(04), fFormat.format(2000));
  writeBlock(mFormat.format(-72));
  
  writeln("");  

  onImpliedCommand(COMMAND_END);
  writeBlock(mFormat.format(30)); // stop program
}

// ************************************************************************************************************************************************************
// Beginn eines neuen Abschnitts
// ************************************************************************************************************************************************************

function onSection() {

  var insertToolCall = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());

  writeln("");

//  if (hasParameter("operation-comment")) {
//    var comment = getParameter("operation-comment");
//  if (comment) {
//    writeComment(comment);
//    }
//  }

  if (insertToolCall) {
    retracted = true;
    
//    onCommand(COMMAND_COOLANT_OFF);

if (tool.comment) {
      writeComment(tool.comment);
    }
    switch (currentSection.jetMode) {
    case JET_MODE_THROUGH:
      writeComment("Brennschneiden Vadura Duesensatz");
      break;
   // case JET_MODE_ETCHING:
//      writeComment("Etch cutting");
//      break;
//    case JET_MODE_VAPORIZE:
//      writeComment("Vaporize cutting");
//      break;
    default:
      error(localize("Unsupported cutting mode."));
    }
  
    switch (tool.type) {
 //   case TOOL_WATER_JET:
//      writeBlock(mFormat.format(36), "T" + toolFormat.format(6)); // waterjet
//      break;
//    case TOOL_LASER_CUTTER:
//      writeBlock(mFormat.format(36), "T" + toolFormat.format(5)); // laser
//      break;
    case TOOL_PLASMA_CUTTER:
      // process 1 - use T2 for process 2
      writeBlock(mFormat.format(36), "T" + toolFormat.format(1)); // plasma
      // to retract hight
      writeComment("Zuendposition anfahren");
      writeBlock(gMotionModal.format(0), xOutput.format(0), yOutput.format(0), zOutput.format(-50));
      writeComment("Zuenden der Heizflamme");
      writeBlock(mFormat.format(72));
      writeBlock(gFormat.format(04), fFormat.format(2000));
      writeBlock(mFormat.format(71));
      writeComment("Warten auf Bestaetigung des Bedieners");
      writeBlock(mFormat.format(00));
      break;
    /*
	case TOOL_MARKER:
      writeBlock(mFormat.format(36), "T" + toolFormat.format(3)); // marker 1 - use 4 for marker 2
      break;
    */
	default:
      error(localize("The CNC does not support the required tool."));
      return;
    }    
      writeln("");
  }

  forceXYZ();

  { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }


  forceAny();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  
// ************************************************************************************************************************************************************  
/*
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
  } */
// ************************************************************************************************************************************************************

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
  if (properties.showSequenceNumbers) {
    writeWords2("N" + nFormat.format(sequenceNumber), arguments);
    sequenceNumber += properties.sequenceNumberIncrement;
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
// Kommentare aus Fusion360
// ************************************************************************************************************************************************************

function onComment(message) {
  writeComment(message);
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
// Schalten der Werkzeugmaschinen und Übergabefunktion aus Fusion360
// ************************************************************************************************************************************************************

function onPower(power) {
  setDeviceMode(power);
}

var deviceOn = false;

function setDeviceMode(enable) {
  if (enable != deviceOn) {
    deviceOn = enable;
    if (enable) {
      switch (tool.type) {
      default:
        // to working plane
        writeComment("Arbeitshoehe anfahren");
        writeBlock(gMotionModal.format(0), zOutput.format(0));
        writeComment("Vorheizen");
        writeBlock(gMotionModal.format(04), fFormat.format(5000));
        writeComment("Schneidsauerstoff ein");
        writeBlock(mFormat.format(73));
        writeln("");
    
       }
    } else {
      switch (tool.type) {
      default:
        //to retract plane
        writeln("");
        writeComment("Schneidsauerstoff aus");
        writeBlock(mFormat.format(-73));
        writeComment("Rueckzugshoehe anfahren");
        writeBlock(gMotionModal.format(0), zOutput.format(-50));
        writeln("");
      }
    }
  }
}

// ************************************************************************************************************************************************************
// nicht unterstützte und ??benötigte?? Funktionsaufrufe
// ************************************************************************************************************************************************************
/*
function onRapid5D(_x, _y, _z, _a, _b, _c) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function onCycle() {
  onError("Drilling is not supported by CNC.");
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeBlock(gFormat.format(4), "X" + secFormat.format(seconds));
}

var mapCommand = {
  COMMAND_STOP:0,
  COMMAND_OPTIONAL_STOP:1,
  COMMAND_END:2
};

function onCommand(command) {
  switch (command) {
  case COMMAND_POWER_ON:
    return;
  case COMMAND_POWER_OFF:
    return;
  case COMMAND_COOLANT_ON:
    return;
  case COMMAND_COOLANT_OFF:
    return;
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

*/
/*
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
        if (properties.allowHeadSwitches) {
          writeln("");
          writeComment("Switch to piercing head before continuing");
          onCommand(COMMAND_STOP);
          writeln("");
        }
      }
    } else if (value == "cutting") {
      if (cuttingSequence == "piercing") {
        if (properties.allowHeadSwitches) {
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
*/
