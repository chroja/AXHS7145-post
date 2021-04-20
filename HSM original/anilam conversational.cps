/**
  Copyright (C) 2012-2014 by Autodesk, Inc.
  All rights reserved.

  Anilam Conversational post processor configuration.

  $Revision: 40091 $
  $Date: 2015-10-14 17:29:32 +0200 (on, 14 okt 2015) $
  
  FORKID {C4FB2934-8767-4e3e-9C3A-4655B6BD858B}
*/

description = "Generic Anilam Conversational";
vendor = "Autodesk, Inc.";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2014 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 24000;

extension = "m";
setCodePage("ascii");

tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion



// user-defined properties
properties = {
  writeMachine: true, // write machine
  writeTools: true, // writes the tools
  optionalStop: true, // optional stop
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  useRadius: false // specifies that arcs should be output using the radius (R word) instead of the I, J, and K words.
};

var gotZAxis = true;



var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var mapCoolantTable = new Table(
  [9, 8],
  {initial:COOLANT_OFF, force:true},
  "Invalid coolant mode"
);

var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var rFormat = xyzFormat; // radius
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var feedFormat = createFormat({decimals:(unit == MM ? 0 : 1)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:1}); // seconds - range 0.1-99999.9
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X "}, xyzFormat);
var yOutput = createVariable({prefix:"Y "}, xyzFormat);
var zOutput = createVariable({prefix:"Z "}, xyzFormat);
var aOutput = createVariable({prefix:"A "}, abcFormat);
var bOutput = createVariable({prefix:"B "}, abcFormat);
var cOutput = createVariable({prefix:"C "}, abcFormat);
var feedOutput = createVariable({prefix:"Feed "}, feedFormat);

// circular output
var iOutput = createVariable({prefix:"I ", force:true}, xyzFormat);
var jOutput = createVariable({prefix:"J ", force:true}, xyzFormat);
var kOutput = createVariable({prefix:"K ", force:true}, xyzFormat);

/**
  Writes the specified block.
*/
function writeBlock() {
  writeWords(arguments);
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln("* " + filterText(String(text).toUpperCase(), permittedCommentChars));
}

function onOpen() {
  if (!gotZAxis) {
    zOutput.disable();
  }
  
  if (!machineConfiguration.isMachineCoordinate(0)) {
    aOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(1)) {
    bOutput.disable();
  }
  if (!machineConfiguration.isMachineCoordinate(2)) {
    cOutput.disable();
  }
  
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  if (programName) {
    writeComment(programName);
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

  // dump tool information
  if (properties.writeTools) {
    var zRanges = {};
    if (is3D()) {
      var numberOfSections = getNumberOfSections();
      for (var i = 0; i < numberOfSections; ++i) {
        var section = getSection(i);
        var zRange = section.getGlobalZRange();
        var tool = section.getTool();
        if (zRanges[tool.number]) {
          zRanges[tool.number].expandToRange(zRange);
        } else {
          zRanges[tool.number] = zRange;
        }
      }
    }

    var tools = getToolTable();
    if (tools.getNumberOfTools() > 0) {
      for (var i = 0; i < tools.getNumberOfTools(); ++i) {
        var tool = tools.getTool(i);
        var comment = "Tool# " + toolFormat.format(tool.number) + "  " +
          "D=" + xyzFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + xyzFormat.format(tool.cornerRadius);
        if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
          comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
        }
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + xyzFormat.format(zRanges[tool.number].getMinimum());
        }
        comment += " - " + getToolTypeName(tool.type);
        writeComment(comment);
      }
    }
  }
  
  if (false) {
    // check for duplicate tool number
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var sectioni = getSection(i);
      var tooli = sectioni.getTool();
      for (var j = i + 1; j < getNumberOfSections(); ++j) {
        var sectionj = getSection(j);
        var toolj = sectionj.getTool();
        if (tooli.number == toolj.number) {
          if (xyzFormat.areDifferent(tooli.diameter, toolj.diameter) ||
              xyzFormat.areDifferent(tooli.cornerRadius, toolj.cornerRadius) ||
              abcFormat.areDifferent(tooli.taperAngle, toolj.taperAngle) ||
              (tooli.numberOfFlutes != toolj.numberOfFlutes)) {
            error(
              subst(
                localize("Using the same tool number for different cutter geometry for operation '%1' and '%2'."),
                sectioni.hasParameter("operation-comment") ? sectioni.getParameter("operation-comment") : ("#" + (i + 1)),
                sectionj.hasParameter("operation-comment") ? sectionj.getParameter("operation-comment") : ("#" + (j + 1))
              )
            );
            return;
          }
        }
      }
    }
  }

  // absolute coordinates and feed per min
  writeBlock("Dim", "Abs");
  writeBlock("Plane", "XY");

  switch (unit) {
  case IN:
    writeBlock("Unit", "Inch");
    break;
  case MM:
    writeBlock("Unit", "MM");
    break;
  }
}

function onComment(message) {
  writeComment(message);
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
  zOutput.reset();
}

/** Force output of A, B, and C. */
function forceABC() {
  aOutput.reset();
  bOutput.reset();
  cOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  feedOutput.reset();
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function setWorkPlane(abc) {
  if (!machineConfiguration.isMultiAxisConfiguration()) {
    return; // ignore
  }

  if (!((currentWorkPlaneABC == undefined) ||
        abcFormat.areDifferent(abc.x, currentWorkPlaneABC.x) ||
        abcFormat.areDifferent(abc.y, currentWorkPlaneABC.y) ||
        abcFormat.areDifferent(abc.z, currentWorkPlaneABC.z))) {
    return; // no change
  }

  onCommand(COMMAND_UNLOCK_MULTI_AXIS);

  // NOTE: add retract here

  writeBlock(
    "Rapid",
    conditional(machineConfiguration.isMachineCoordinate(0), "A" + abcFormat.format(abc.x)),
    conditional(machineConfiguration.isMachineCoordinate(1), "B" + abcFormat.format(abc.y)),
    conditional(machineConfiguration.isMachineCoordinate(2), "C" + abcFormat.format(abc.z))
  );
  
  onCommand(COMMAND_LOCK_MULTI_AXIS);

  currentWorkPlaneABC = abc;
}

var closestABC = false; // choose closest machine angles
var currentMachineABC;

function getWorkPlaneMachineABC(workPlane) {
  var W = workPlane; // map to global frame

  var abc = machineConfiguration.getABC(W);
  if (closestABC) {
    if (currentMachineABC) {
      abc = machineConfiguration.remapToABC(abc, currentMachineABC);
    } else {
      abc = machineConfiguration.getPreferredABC(abc);
    }
  } else {
    abc = machineConfiguration.getPreferredABC(abc);
  }
  
  try {
    abc = machineConfiguration.remapABC(abc);
    currentMachineABC = abc;
  } catch (e) {
    error(
      localize("Machine angles not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }
  
  var direction = machineConfiguration.getDirection(abc);
  if (!isSameDirection(direction, W.forward)) {
    error(localize("Orientation not supported."));
  }
  
  if (!machineConfiguration.isABCSupported(abc)) {
    error(
      localize("Work plane is not supported") + ":"
      + conditional(machineConfiguration.isMachineCoordinate(0), " A" + abcFormat.format(abc.x))
      + conditional(machineConfiguration.isMachineCoordinate(1), " B" + abcFormat.format(abc.y))
      + conditional(machineConfiguration.isMachineCoordinate(2), " C" + abcFormat.format(abc.z))
    );
  }

  var tcp = true;
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);
  }
  
  return abc;
}

function onSection() {
  var insertToolCall = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());
  if (insertToolCall || newWorkOffset || newWorkPlane) {
    
    // retract to safe plane
    retracted = true;
    if (gotZAxis) {
      writeBlock("Rapid", "Z" + xyzFormat.format(0), "Tool#", toolFormat.format(0));
    } else {
      writeComment("RETRACT MANUALLY");
    }
    zOutput.reset();
  }

  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }
  
  if (insertToolCall) {
    forceWorkPlane();
    
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }

    writeBlock("Tool#", toolFormat.format(tool.number));
    if (tool.comment) {
      writeComment(tool.comment);
    }
    var showToolZMin = false;
    if (showToolZMin) {
      if (is3D()) {
        var numberOfSections = getNumberOfSections();
        var zRange = currentSection.getGlobalZRange();
        var number = tool.number;
        for (var i = currentSection.getId() + 1; i < numberOfSections; ++i) {
          var section = getSection(i);
          if (section.getTool().number != number) {
            break;
          }
          zRange.expandToRange(section.getGlobalZRange());
        }
        writeComment(localize("ZMIN") + "=" + zRange.getMinimum());
      }
    }
  } else if (retracted) {
    writeBlock("Tool#", toolFormat.format(tool.number));
  }
  
  if (retracted ||
      insertToolCall ||
      isFirstSection() ||
      (rpmFormat.areDifferent(tool.spindleRPM, getPreviousSection().getTool().spindleRPM)) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (tool.spindleRPM < 1) {
      error(localize("Spindle speed out of range."));
      return;
    }
    if (tool.spindleRPM > 99999) {
      warning(localize("Spindle speed exceeds maximum value."));
    }
    writeBlock(
      "RPM", rpmFormat.format(tool.spindleRPM), mFormat.format(tool.clockwise ? 3 : 4)
    );
  }

  // wcs
  var workOffset = currentSection.workOffset;
  if (workOffset >= 0) {
    if (workOffset > 9) {
      error(localize("Work offset out of range."));
    } else {
      writeBlock("Offset", "Fixture#", workOffset);
    }
  }

  forceXYZ();

  if (machineConfiguration.isMultiAxisConfiguration()) { // use 5-axis indexing for multi-axis mode
    // set working plane after datum shift

    var abc = new Vector(0, 0, 0);
    if (currentSection.isMultiAxis()) {
      forceWorkPlane();
      cancelTransformation();
    } else {
      abc = getWorkPlaneMachineABC(currentSection.workPlane);
    }
    setWorkPlane(abc);
  } else { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  // set coolant after we have positioned at Z
  {
    var c = mapCoolantTable.lookup(tool.coolant);
    if (c) {
      writeBlock(mFormat.format(c));
    } else {
      warning(localize("Coolant not supported."));
    }
  }

  forceAny();
  
  var initialPosition = getFramePosition(currentSection.getInitialPosition());
  if (!retracted) {
    if (getCurrentPosition().z < initialPosition.z) {
      if (gotZAxis) {
        writeBlock("Rapid", zOutput.format(initialPosition.z));
      } else {
        writeComment("Reposition to Z" + xyzFormat.format(initialPosition.z));
      }
    }
  }

  if (insertToolCall) {
    var lengthOffset = tool.lengthOffset;
    if (lengthOffset > 99) {
      error(localize("Length offset out of range."));
      return;
    }
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  if (seconds < secFormat.getMinimumValue()) {
    second = secFormat.getMinimumValue();
  }
  writeBlock("Dwell", secFormat.format(seconds));
}

function onSpindleSpeed(spindleSpeed) {
  writeBlock(
    "RPM", rpmFormat.format(spindleSpeed), mFormat.format(tool.clockwise ? 3 : 4)
  );
}

function onCycle() {
  writeBlock("Plane", "XY");
}

function getCommonCycle(x, y, z, r, c) {
  forceXYZ();
  return [xOutput.format(x), yOutput.format(y),
    "ZDepth" + xyzFormat.format(z),
    "StartHgt" + xyzFormat.format(r),
    "ReturnHgt" + xyzFormat.format(c)];
}

function onCyclePoint(x, y, z) {
  if (isFirstCyclePoint()) {
    repositionToCycleClearance(cycle, x, y, z);
    
    var F = cycle.feedrate;
    var P = clamp(secFormat.getMinimumValue(), cycle.dwell, 99999.999); // in seconds

    switch (cycleType) {
    case "drilling":
      writeBlock(
        "BasicDrill",
        getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
        feedOutput.format(F)
      );
      break;
    case "counter-boring":
      if (P > 0) {
        writeBlock(
          "BasicDrill",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          "Dwell", secFormat.format(P),
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          "BasicDrill",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          feedOutput.format(F)
        );
      }
      break;
    case "chip-breaking":
      // cycle.accumulatedDepth is ignored
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeBlock(
          "PeckDrill",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          "Peck", xyzFormat.format(cycle.incrementalDepth),
          feedOutput.format(F)
        );
      }
      break;
    case "deep-drilling":
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeBlock(
          "PeckDrill",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          "Peck", xyzFormat.format(cycle.incrementalDepth),
          "Dwell", secFormat.format(P),
          feedOutput.format(F)
        );
      }
      break;
    //case "tapping":
    //  break;
    //case "left-tapping":
    //  break;
    //case "right-tapping":
    //  break;
    //case "fine-boring":
    //  break;
    //case "back-boring":
    //  break;
    case "reaming":
      if (P > 0) {
        writeBlock(
          "Boring",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          "Dwell", secFormat.format(P),
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          "Boring",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          feedOutput.format(F)
        );
      }
      break;
    //case "stop-boring":
    //  break;
    //case "manual-boring":
    //  break;
    case "boring":
      if (P > 0) {
        writeBlock(
          "Boring",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          "Dwell", secFormat.format(P),
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          "Boring",
          getCommonCycle(x, y, cycle.retract - cycle.bottom, cycle.retract, cycle.clearance),
          feedOutput.format(F)
        );
      }
      break;
    default:
      expandCyclePoint(x, y, z);
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else {
      writeBlock(xOutput.format(x), yOutput.format(y));
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    writeBlock("Drilling", "Off");
    zOutput.reset();
  }
  feedOutput.reset();
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

function onRapid(_x, _y, _z) {
  if (!gotZAxis) {
    if (xyzFormat.areDifferent(_z, getCurrentPosition().z)) {
      writeComment("Reposition to Z" + xyzFormat.format(_z));
    }
  }

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    writeBlock("Rapid", x, y, z);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  if (!gotZAxis) {
    if (xyzFormat.areDifferent(_z, getCurrentPosition().z)) {
      writeComment("Reposition to Z" + xyzFormat.format(_z));
    }
  }
  
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = feedOutput.format(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock("Line", x, y, z, f, "ToolComp", "Left");
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock("Line", x, y, z, f, "ToolComp", "Right");
        break;
      default:
        writeBlock("Line", x, y, z, f, "ToolComp", "Off");
      }
    } else {
      writeBlock("Line", x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock("Line", f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    return;
  }
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation mode cannot be changed at rapid traversal."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  writeBlock("Rapid", x, y, z, a, b, c);
  feedOutput.reset();
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("This post configuration has not been customized for 5-axis simultaneous toolpath."));
    return;
  }
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for 5-axis move."));
    return;
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var a = aOutput.format(_a);
  var b = bOutput.format(_b);
  var c = cOutput.format(_c);
  var f = feedOutput.format(feed);
  if (x || y || z || a || b || c) {
    writeBlock("Line", x, y, z, a, b, c, f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock("Line", f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }
  
  // TAG: linearize helix if not supported
  // TAG: add support for Spiral
  
  if (!gotZAxis) {
    if (isHelical()) {
      error(localize("Helical arcs are not supported by the CNC."));
      return;
    }

    if (getCircularPlane() != PLANE_XY) {
      error(localize("Not XY-plane arcs are not supported by the CNC."));
      return;
    }
    
    if (xyzFormat.areDifferent(z, getCurrentPosition().z)) {
      writeComment("Reposition to Z" + xyzFormat.format(z));
    }
  }
  
  if (isFullCircle()) {
    if (properties.useRadius || isHelical()) { // radius mode does not support full arcs
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock("Plane", "XY");
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", iOutput.format(cx), jOutput.format(cy), feedOutput.format(feed));
      break;
    case PLANE_ZX:
      writeBlock("Plane", "XZ");
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", iOutput.format(cx), kOutput.format(cz), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock("Plane", "YZ");
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", jOutput.format(cy), kOutput.format(cz), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else if (!properties.useRadius) {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock("Plane", "XY");
      xOutput.reset();
      yOutput.reset();
      if (isHelical()) {
        writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx), jOutput.format(cy), feedOutput.format(feed));
      } else {
        writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx), jOutput.format(cy), feedOutput.format(feed));
      }
      break;
    case PLANE_ZX:
      if (isHelical()) {
        linearize(tolerance);
        return;
      }
      writeBlock("Plane", "XZ");
      zOutput.reset();
      xOutput.reset();
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx), kOutput.format(cz), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      if (isHelical()) {
        linearize(tolerance);
        return;
      }
      writeBlock("Plane", "YZ");
      yOutput.reset();
      zOutput.reset();
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy), kOutput.format(cz), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else { // use radius mode
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock("Plane", "XY");
      xOutput.reset();
      yOutput.reset();
      if (isHelical()) {
        writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), "Radius", rFormat.format(r), feedOutput.format(feed));
      } else {
        writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), "Radius", rFormat.format(r), feedOutput.format(feed));
      }
      break;
    case PLANE_ZX:
      writeBlock("Plane", "XZ");
      zOutput.reset();
      xOutput.reset();
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), "Radius", rFormat.format(r), feedOutput.format(feed));
      break;
    case PLANE_YZ:
      writeBlock("Plane", "YZ");
      yOutput.reset();
      zOutput.reset();
      writeBlock("Arc", clockwise ? "Cw" : "Ccw", xOutput.format(x), yOutput.format(y), zOutput.format(z), "Radius", rFormat.format(r), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  COMMAND_SPINDLE_CLOCKWISE:3,
  COMMAND_SPINDLE_COUNTERCLOCKWISE:4,
  COMMAND_STOP_SPINDLE:5,
  COMMAND_COOLANT_ON:8, // flood
  COMMAND_COOLANT_OFF:9
};

function onCommand(command) {
  switch (command) {
  case COMMAND_OPTIONAL_STOP: // not supported for all
    // writeBlock(mFormat.format(1));
    return;
  case COMMAND_START_SPINDLE:
    onCommand(tool.clockwise ? COMMAND_SPINDLE_CLOCKWISE : COMMAND_SPINDLE_COUNTERCLOCKWISE);
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

function onSectionEnd() {
  writeBlock("Plane", "XY");
  forceAny();
}

function onClose() {
  onCommand(COMMAND_COOLANT_OFF);

  if (gotZAxis) {
    writeBlock("Rapid", "Z" + xyzFormat.format(0), "Tool#", toolFormat.format(0));
  } else {
    writeComment("RETRACT MANUALLY");
  }
  zOutput.reset();

  setWorkPlane(new Vector(0, 0, 0)); // reset working plane

  if (!machineConfiguration.hasHomePositionX() && !machineConfiguration.hasHomePositionY()) {
    writeBlock("Rapid", "X" + xyzFormat.format(0), "Y" + xyzFormat.format(0)); // return to home
  } else {
    var homeX;
    if (machineConfiguration.hasHomePositionX()) {
      homeX = "X" + xyzFormat.format(machineConfiguration.getHomePositionX());
    }
    var homeY;
    if (machineConfiguration.hasHomePositionY()) {
      homeY = "Y" + xyzFormat.format(machineConfiguration.getHomePositionY());
    }
    writeBlock("Rapid", homeX, homeY);
  }

  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock("EndMain"); // end of program
}
