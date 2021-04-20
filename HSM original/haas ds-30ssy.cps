/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  HAAS Lathe post processor configuration.

  $Revision: 40489 $
  $Date: 2015-12-18 09:40:28 +0100 (fr, 18 dec 2015) $

  FORKID {14D60AD3-4366-49dc-939C-4DB5EA48FF68}
*/

description = "HAAS DS-30SSY";
vendor = "Haas Automation";
vendorUrl = "https://www.haascnc.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 24000;

longDescription = "Preconfigured HAAS DS-30SSY lathe post with support for mill-turn.";

extension = "nc";
programNameIsInteger = true;
setCodePage("ascii");

capabilities = CAPABILITY_MILLING | CAPABILITY_TURNING;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.01, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(120); // reduced sweep due to G112 support
allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
allowSpiralMoves = false;
highFeedrate = (unit == IN) ? 470 : 12000;


// user-defined properties
properties = {
  writeMachine: false, // write machine
  writeTools: false, // writes the tools
  // preloadTool: false, // preloads next tool on tool change if any
  showSequenceNumbers: false, // show sequence numbers
  sequenceNumberStart: 10, // first sequence number
  sequenceNumberIncrement: 1, // increment for sequence numbers
  optionalStop: true, // optional stop
  separateWordsWithSpace: true, // specifies that the words should be separated with a white space
  useRadius: true, // specifies that arcs should be output using the radius (R word) instead of the I, J, and K words.
  maximumSpindleSpeed: 4800, // specifies the maximum spindle speed
  useParametricFeed: false, // specifies that feed should be output using Q values
  showNotes: false, // specifies that operation notes should be output.
  useCycles: true, // specifies that drilling cycles should be used.
  G53HomePosition_X: 0, // home position for X-axis
  G53HomePosition_Y: 0, // home position for Y-axis
  G53HomePosition_Z: 0, // home position for Z-axis
  G53HomePositionSub_Z: 0, // home Position for Z when the operation uses the Secondary Spindle 
  gotPartCatcher: false, // specifies if the machine has a part catcher
  useTailStock: false, // specifies to use the tailstock or not
  gotChipConveyor: false // specifies to use a chip conveyor Y/N

  /* // requires customization
  transBClearance: -5, // stock transfer B clearance plane - First Position relative to B offset
  transBPosition: -7, // stock transfer B position plane - Position on Part relative to B offset
  transFeedrate: 75 // stock transfer feedrate
  */
};



var permittedCommentChars = " ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.,=_-";

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var spatialFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:2}); // diameter mode & IS SCALING POLAR COORDINATES
var yFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var zFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var rFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true}); // radius
var abcFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG});
var cFormat = createFormat({decimals:3, forceDecimal:true, scale:DEG, cyclicLimit:Math.PI*2});
var feedFormat = createFormat({decimals:(unit == MM ? 2 : 3), forceDecimal:true});
var pitchFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-99999.999
var milliFormat = createFormat({decimals:0}); // milliseconds // range 1-9999
var taperFormat = createFormat({decimals:1, scale:DEG});

var xOutput = createVariable({prefix:"X"}, xFormat);
var yOutput = createVariable({prefix:"Y"}, yFormat);
var zOutput = createVariable({prefix:"Z"}, zFormat);
var aOutput = createVariable({prefix:"A"}, abcFormat);
var bOutput = createVariable({prefix:"B"}, abcFormat);
var cOutput = createVariable({prefix:"C"}, cFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);
var pitchOutput = createVariable({prefix:"F", force:true}, pitchFormat);
var sOutput = createVariable({prefix:"S", force:true}, rpmFormat);
var pOutput = createVariable({prefix:"P", force:true}, rpmFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I", force:true}, spatialFormat);
var jOutput = createReferenceVariable({prefix:"J", force:true}, spatialFormat);
var kOutput = createReferenceVariable({prefix:"K", force:true}, spatialFormat);

var g92IOutput = createVariable({prefix:"I"}, zFormat); // no scaling

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gPlaneModal = createModal({onchange:function () {gMotionModal.reset();}}, gFormat); // modal group 2 // G17-19
var gFeedModeModal = createModal({}, gFormat); // modal group 5 // G98-99
var gSpindleModeModal = createModal({}, gFormat); // modal group 5 // G96-97
var gSpindleModal = createModal({}, gFormat); // G14/G15 SPINDLE MODE
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21
var gCycleModal = createModal({}, gFormat); // modal group 9 // G81, ...
var gPolarModal = createModal({}, gFormat); // G112, G113
var cAxisModalFormat = createModal({}, mFormat); 

// fixed settings
var firstFeedParameter = 100;

var gotYAxis = true;
var yAxisMinimum = toPreciseUnit(gotYAxis ? -50.8 : 0, MM); // specifies the mimimum range for the Y-axis
var yAxisMaximum = toPreciseUnit(gotYAxis ? 50.8 : 0, MM); // specifies the maximum range for the Y-axis
var xAxisMinimum = toPreciseUnit(0, MM); // specifies the maximum range for the X-axis (RADIUS MODE VALUE)

var gotLiveTooling = true; // specifies if the machine is able to do live tooling
var gotCAxis = true;
var gotSecondarySpindle = true;
var gotDoorControl = false;
var gotBarFeeder = false;
var gotMultiTurret = false; // specifies if the machine has several turrets

var WARNING_WORK_OFFSET = 0;

// collected state
var sequenceNumber;
var currentWorkOffset;
var optionalSection = false;
var forceSpindleSpeed = false;
var activeMovements; // do not use by default
var currentFeedId;
var maximumCircularRadiiDifference = toPreciseUnit(0.005, MM);

/** Returns the modulus. */
function getModulus(x, y) {
  return Math.sqrt(x * x + y * y);
}

/** Returns the required number of segments for linearization of the corresponding arc segment. */
function getNumberOfSegments(radius, sweep, error) {
  if (radius > error) {
    var stepAngle = 2 * Math.acos(1 - error/radius);
    return Math.max(Math.ceil(sweep/stepAngle), 1);
  }
  return 1;
}

/**
  Returns the C rotation for the given X and Y coordinates.
*/
function getC(x, y) {
  return Math.atan2(y, x);
}

/**
  Returns the C rotation for the given X and Y coordinates in the desired rotary direction.
*/
function getCClosest(x, y, _c, clockwise) {
  if (_c == Number.POSITIVE_INFINITY) {
    _c = 0; // undefined
  }
  var c = getC(x, y);
  if (clockwise != undefined) {
    if (clockwise) {
      while (c < _c) {
        c += Math.PI * 2;
      }
    } else {
      while (c > _c) {
        c -= Math.PI * 2;
      }
    }
  } else {
    min = _c - Math.PI;
    max = _c + Math.PI;
    while (c < min) {
      c += Math.PI * 2;
    }
    while (c > max) {
      c -= Math.PI * 2;
    }
  }
  return c;
}

/**
  Returns the desired tolerance for the given section.
*/
function getTolerance() {
  var t = tolerance;
  if (hasParameter("operation:tolerance")) {
    if (t > 0) {
      t = Math.min(t, getParameter("operation:tolerance"));
    } else {
      t = getParameter("operation:tolerance");
    }
  }
  return t;
}

/**
  Writes the specified block.
*/
function writeBlock() {
  if (properties.showSequenceNumbers) {
    if (sequenceNumber > 99999) {
      sequenceNumber = properties.sequenceNumberStart;
    }
    if (optionalSection) {
      var text = formatWords(arguments);
      if (text) {
        writeWords("/", "N" + sequenceNumber, text);
      }
    } else {
      writeWords2("N" + sequenceNumber, arguments);
    }
    sequenceNumber += properties.sequenceNumberIncrement;
  } else {
    if (optionalSection) {
      writeWords2("/", arguments);
    } else {
      writeWords(arguments);
    }
  }
}

/**
  Writes the specified optional block.
*/
function writeOptionalBlock() {
  if (properties.showSequenceNumbers) {
    var words = formatWords(arguments);
    if (words) {
      writeWords("/", "N" + sequenceNumber, words);
      sequenceNumber += properties.sequenceNumberIncrement;
    }
  } else {
    writeWords2("/", arguments);
  }
}

function formatComment(text) {
  return "(" + String(text).replace(/[\(\)]/g, "") + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

var machineConfigurationZ;
var machineConfigurationXC;
var machineConfigurationXB;

function onOpen() {

  if (true) {
    machineConfigurationZ = new MachineConfiguration();

    if (gotCAxis) {
      var cAxis = createAxis({coordinate:2, table:true, axis:[0, 0, 1], cyclic:true, preference:0}); // C axis is modal between primary and secondary spindle
      machineConfigurationXC = new MachineConfiguration(cAxis);
      machineConfigurationXC.setSpindleAxis(new Vector(1, 0, 0));
    }
  }
  
  machineConfigurationXC.setVendor("HAAS");
  machineConfigurationXC.setModel("DS30SSY");
  
  if (!gotYAxis) {
    yOutput.disable();
  }
  aOutput.disable();
  if (!machineConfigurationXB) {
    bOutput.disable();
  }
  if (!machineConfigurationXC) {
    cOutput.disable();
  }

  if (highFeedrate <= 0) {
    error(localize("You must set 'highFeedrate' because axes are not synchronized for rapid traversal."));
    return;
  }
  
  if (!properties.separateWordsWithSpace) {
    setWordSeparator("");
  }

  sequenceNumber = properties.sequenceNumberStart;
  writeln("%");

  if (programName) {
    var programId;
    try {
      programId = getAsInt(programName);
    } catch(e) {
      error(localize("Program name must be a number."));
      return;
    }
    if (!((programId >= 1) && (programId <= 99999))) {
      error(localize("Program number is out of range."));
      return;
    }
    var oFormat = createFormat({width:5, zeropad:true, decimals:0});
    if (programComment) {
      writeln("O" + oFormat.format(programId) + " (" + filterText(String(programComment).toUpperCase(), permittedCommentChars) + ")");
    } else {
      writeln("O" + oFormat.format(programId));
    }
  } else {
    error(localize("Program name has not been specified."));
    return;
  }

  // dump machine configuration
  var vendor = machineConfigurationXC.getVendor();
  var model = machineConfigurationXC.getModel();
  var description = machineConfigurationXC.getDescription();

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
        var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
        var comment = "T" + toolFormat.format(tool.number * 100 + compensationOffset % 100) + " " +
          "D=" + spatialFormat.format(tool.diameter) + " " +
          localize("CR") + "=" + spatialFormat.format(tool.cornerRadius);
        if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
          comment += " " + localize("TAPER") + "=" + taperFormat.format(tool.taperAngle) + localize("deg");
        }
        if (zRanges[tool.number]) {
          comment += " - " + localize("ZMIN") + "=" + spatialFormat.format(zRanges[tool.number].getMinimum());
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
          if (spatialFormat.areDifferent(tooli.diameter, toolj.diameter) ||
              spatialFormat.areDifferent(tooli.cornerRadius, toolj.cornerRadius) ||
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
  writeBlock(gFeedModeModal.format(98), gPlaneModal.format(18));

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(20));
    break;
  case MM:
    writeBlock(gUnitModal.format(21));
    break;
  }

  // writeBlock("#" + (firstFeedParameter - 1) + "=" + ((currentSection.spindle == SPINDLE_SECONDARY) ? properties.G53HomePositionSub_Z : properties.G53HomePosition_Z), formatComment("G53HomePosition_Z"));
  
  var usesPrimarySpindle = false;
  var usesSecondarySpindle = false;
  for (var i = 0; i < getNumberOfSections(); ++i) {
    var section = getSection(i);
    if (section.getType() != TYPE_TURNING) {
      continue;
    }
    switch (section.spindle) {
    case SPINDLE_PRIMARY:
      usesPrimarySpindle = true;
      break;
    case SPINDLE_SECONDARY:
      usesSecondarySpindle = true;
      break;
    }
  }
  
  writeBlock(gFormat.format(50), sOutput.format(properties.maximumSpindleSpeed));
  sOutput.reset();

  if (properties.gotChipConveyor) {
    onCommand(COMMAND_START_CHIP_TRANSPORT);
  }
  
  if (gotYAxis) {
    writeBlock(gFormat.format(53), gMotionModal.format(0), "Y" + yFormat.format(properties.G53HomePosition_Y)); // retract
  }
  writeBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(properties.G53HomePosition_X)); // retract
  if (gotSecondarySpindle) {
    writeBlock(gFormat.format(53), gMotionModal.format(0), "B" + abcFormat.format(0)); // retract Sub Spindle if applicable 
  }
  writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format(properties.G53HomePosition_Z)); // retract
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

function forceFeed() {
  currentFeedId = undefined;
  feedOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  forceABC();
  forceFeed();
}

function FeedContext(id, description, feed) {
  this.id = id;
  this.description = description;
  this.feed = feed;
}

function getFeed(f) {
  if (activeMovements) {
    var feedContext = activeMovements[movement];
    if (feedContext != undefined) {
      if (!feedFormat.areDifferent(feedContext.feed, f)) {
        if (feedContext.id == currentFeedId) {
          return ""; // nothing has changed
        }
        forceFeed();
        currentFeedId = feedContext.id;
        return "F#" + (firstFeedParameter + feedContext.id);
      }
    }
    currentFeedId = undefined; // force Q feed next time
  }
  return feedOutput.format(f); // use feed value
}

function initializeActiveFeeds() {
  activeMovements = new Array();
  var movements = currentSection.getMovements();

  var id = 0;
  var activeFeeds = new Array();
  if (hasParameter("operation:tool_feedCutting")) {
    if (movements & ((1 << MOVEMENT_CUTTING) | (1 << MOVEMENT_LINK_TRANSITION) | (1 << MOVEMENT_EXTENDED))) {
      var feedContext = new FeedContext(id, localize("Cutting"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_CUTTING] = feedContext;
      activeMovements[MOVEMENT_LINK_TRANSITION] = feedContext;
      activeMovements[MOVEMENT_EXTENDED] = feedContext;
    }
    ++id;
    if (movements & (1 << MOVEMENT_PREDRILL)) {
      feedContext = new FeedContext(id, localize("Predrilling"), getParameter("operation:tool_feedCutting"));
      activeMovements[MOVEMENT_PREDRILL] = feedContext;
      activeFeeds.push(feedContext);
    }
    ++id;
  }
  
  if (hasParameter("operation:finishFeedrate")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:finishFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting")) {
    if (movements & (1 << MOVEMENT_FINISH_CUTTING)) {
      var feedContext = new FeedContext(id, localize("Finish"), getParameter("operation:tool_feedCutting"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_FINISH_CUTTING] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:tool_feedEntry")) {
    if (movements & (1 << MOVEMENT_LEAD_IN)) {
      var feedContext = new FeedContext(id, localize("Entry"), getParameter("operation:tool_feedEntry"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_IN] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LEAD_OUT)) {
      var feedContext = new FeedContext(id, localize("Exit"), getParameter("operation:tool_feedExit"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LEAD_OUT] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:noEngagementFeedrate")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), getParameter("operation:noEngagementFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  } else if (hasParameter("operation:tool_feedCutting") &&
             hasParameter("operation:tool_feedEntry") &&
             hasParameter("operation:tool_feedExit")) {
    if (movements & (1 << MOVEMENT_LINK_DIRECT)) {
      var feedContext = new FeedContext(id, localize("Direct"), Math.max(getParameter("operation:tool_feedCutting"), getParameter("operation:tool_feedEntry"), getParameter("operation:tool_feedExit")));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_LINK_DIRECT] = feedContext;
    }
    ++id;
  }
  
  if (hasParameter("operation:reducedFeedrate")) {
    if (movements & (1 << MOVEMENT_REDUCED)) {
      var feedContext = new FeedContext(id, localize("Reduced"), getParameter("operation:reducedFeedrate"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_REDUCED] = feedContext;
    }
    ++id;
  }

  if (hasParameter("operation:tool_feedRamp")) {
    if (movements & ((1 << MOVEMENT_RAMP) | (1 << MOVEMENT_RAMP_HELIX) | (1 << MOVEMENT_RAMP_PROFILE) | (1 << MOVEMENT_RAMP_ZIG_ZAG))) {
      var feedContext = new FeedContext(id, localize("Ramping"), getParameter("operation:tool_feedRamp"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_RAMP] = feedContext;
      activeMovements[MOVEMENT_RAMP_HELIX] = feedContext;
      activeMovements[MOVEMENT_RAMP_PROFILE] = feedContext;
      activeMovements[MOVEMENT_RAMP_ZIG_ZAG] = feedContext;
    }
    ++id;
  }
  if (hasParameter("operation:tool_feedPlunge")) {
    if (movements & (1 << MOVEMENT_PLUNGE)) {
      var feedContext = new FeedContext(id, localize("Plunge"), getParameter("operation:tool_feedPlunge"));
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_PLUNGE] = feedContext;
    }
    ++id;
  }
  if (true) { // high feed
    if (movements & (1 << MOVEMENT_HIGH_FEED)) {
      var feedContext = new FeedContext(id, localize("High Feed"), this.highFeedrate);
      activeFeeds.push(feedContext);
      activeMovements[MOVEMENT_HIGH_FEED] = feedContext;
    }
    ++id;
  }
  
  for (var i = 0; i < activeFeeds.length; ++i) {
    var feedContext = activeFeeds[i];
    writeBlock("#" + (firstFeedParameter + feedContext.id) + "=" + feedFormat.format(feedContext.feed), formatComment(feedContext.description));
  }
}

var currentWorkPlaneABC = undefined;

function forceWorkPlane() {
  currentWorkPlaneABC = undefined;
}

function setWorkPlane(abc) {
  // milling only

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

  writeBlock(
    gMotionModal.format(0),
    conditional(machineConfiguration.isMachineCoordinate(0), "A" + abcFormat.format(abc.x)),
    conditional(machineConfiguration.isMachineCoordinate(1), "B" + abcFormat.format(abc.y)),
    conditional(machineConfiguration.isMachineCoordinate(2), "C" + abcFormat.format(abc.z))
  );
  
  onCommand(COMMAND_LOCK_MULTI_AXIS);

  currentWorkPlaneABC = abc;
}

var useXZCMode = false;
var usePolarMode = false;

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

  var tcp = useXZCMode;
  if (tcp) {
    setRotation(W); // TCP mode
  } else {
    var O = machineConfiguration.getOrientation(abc);
    var R = machineConfiguration.getRemainingOrientation(abc, W);
    setRotation(R);
  }
  
  return abc;
}

function getLiveToolingMode(section) {
  if (section.getType() != TYPE_MILLING) {
    return -1;
  }
  var forward = section.workPlane.forward;
  if (isSameDirection(forward, new Vector(0, 0, 1))) {
    // writeln("(Milling from Z+ G17)");
    return 0;
  } else if (isSameDirection(forward, new Vector(0, 0, -1))) {
    return 1;
  } else if (Vector.dot(forward, new Vector(0, 0, 1)) < 1e-7) {
    // writeln("(Milling from X+ G19)");
    return 2;
  } else {
    error(localize("Orientation is not supported by CNC machine."));
    return -1;
  }
}

function getSpindle() {
  if (getNumberOfSections() == 0) {
    return SPINDLE_PRIMARY;
  }
  if (getCurrentSectionId() < 0) {
    return getSection(getNumberOfSections() - 1).spindle == 0;
  }
  if (currentSection.getType() == TYPE_TURNING) {
    return currentSection.spindle;
  } else {
    if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
      return SPINDLE_PRIMARY;
    } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
      if (!gotSecondarySpindle) {
        error(localize("Secondary spindle is not available."));
      }
      return SPINDLE_SECONDARY;
    } else {
      return SPINDLE_PRIMARY;
    }
  }
}

function onSection() {
  writeln("");

  // TAG: "q" in ["q", "t", "r"]  - "q" in {q:1, t:3: r:5} 
  var tapping = hasParameter("operation:cycleType") &&
    ((getParameter("operation:cycleType") == "tapping") ||
     (getParameter("operation:cycleType") == "right-tapping") ||
     (getParameter("operation:cycleType") == "left-tapping"));

  var forceToolAndRetract = optionalSection && !currentSection.isOptional();
  optionalSection = currentSection.isOptional();

  var turning = (currentSection.getType() == TYPE_TURNING);
  
  var insertToolCall = forceToolAndRetract || isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number) ||
    (tool.compensationOffset != getPreviousSection().getTool().compensationOffset) ||
    (tool.diameterOffset != getPreviousSection().getTool().diameterOffset);
  
  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newSpindle = isFirstSection() ||
    (getPreviousSection().spindle != currentSection.spindle);
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());
  var axialCenterDrilling = hasParameter("operation-strategy") && (getParameter("operation-strategy") == "drill") && 
    (currentSection.getNumberOfCyclePoints() == 1) &&
    !xFormat.isSignificant(getFramePosition(currentSection.getInitialPosition()).x) &&
    !yFormat.isSignificant(getFramePosition(currentSection.getInitialPosition()).y) &&
    (currentSection.getType() == TYPE_MILLING)  &&
    (getLiveToolingMode(currentSection) == 0) &&
    (spatialFormat.format(currentSection.getFinalPosition().x) == 0); // catch drill issue for old versions
  var stockTransfer = hasParameter ("operation-strategy") &&
    (getParameter("operation-strategy") == "turningStockTransfer");
  
  if (insertToolCall || newSpindle || newWorkOffset || newWorkPlane && !currentSection.isPatterned()) { 
    // retract to safe plane
    retracted = true;
    // TAG: what about retract when milling along Z+
    if (!isFirstSection()) {
      if (gotYAxis) {
        writeBlock(gFormat.format(53), gMotionModal.format(0), "Y" + yFormat.format(properties.G53HomePosition_Y)); // retract
      }
      writeBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(properties.G53HomePosition_X)); // retract
      writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format((currentSection.spindle == SPINDLE_SECONDARY) ? properties.G53HomePositionSub_Z : properties.G53HomePosition_Z)); // retract with regard to spindle
      xOutput.reset();
    }
  }

  if (currentSection.getType() == TYPE_MILLING) { // handle multi-axis toolpath
    if (!gotLiveTooling) {
      error(localize("Live tooling is not supported by the CNC machine."));
      return;
    }

    var config;
    if (!currentSection.isMultiAxis() && isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
      config = machineConfigurationZ;
    } else if (!currentSection.isMultiAxis() && isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
      error(localize("Milling from Z- is not supported by the CNC machine."));
      return;
    } else {
      switch (currentSection.spindle) {
      case SPINDLE_PRIMARY:
        config = machineConfigurationXC;
        bOutput.disable();
        cOutput.enable();
        break;
      case SPINDLE_SECONDARY:
        config = machineConfigurationXC; // yes - C is intended
        bOutput.disable();
        cOutput.enable();
        break;
      default:
        error(localize("Unsupported spindle."));
        return;
      }
    }
    
    if (!config) {
      error(localize("The requested orientation is not supported by the CNC machine."));
      return;
    }
    setMachineConfiguration(config);
    currentSection.optimizeMachineAnglesByMachine(config, 1); // map tip mode
  }

  /** Polar mode. */
  if (currentSection.getGlobalRange) {
    if ((currentSection.getType() == TYPE_MILLING) &&
        (hasParameter("operation:strategy") && (getParameter("operation:strategy") != "drill")) &&
        !currentSection.isMultiAxis() && (getLiveToolingMode(currentSection) == 0)) {
      if (doesToolpathFitInXYRange(abc)) {
        if (!currentSection.isPatterned()) {
          usePolarMode = false; // use the Y-axis
        } else {
          usePolarMode = true; // needed if there is no Y-Axis
        }
      } else {
        usePolarMode = true; // toolpath does not fit into XY range
      }
    } else {
      usePolarMode = false; 
    }
  } else {
    if (revision < 40000) {
      warning(localize("Please update to the latest release to allow XY linear interpolation instead of polar interpolation."));
    }
    usePolarMode = true; // for older versions without the getGlobalRange() function
  }

  /** XZC mode. */
  if (currentSection.getType() == TYPE_MILLING) {
    if (getLiveToolingMode(currentSection) == 0) { // G17 plane
      useXZCMode = hasParameter("operation-strategy") && (getParameter("operation-strategy") == "drill");
    } else if (getLiveToolingMode(currentSection) == 2) { // G19 plane
      useXZCMode = (hasParameter("operation-strategy") && getParameter("operation-strategy") != "drill" && !doesToolpathFitInXYRange(machineConfiguration.getABC(currentSection.workPlane)));
    } else {
      error(localize("Direction is not supported for XZC Mode"));
      return;
    }
  } else {
    useXZCMode = false; // turning
  }
  
  if (gotCAxis) {
    if (axialCenterDrilling) {
      useXZCMode = false;
      cOutput.disable();
    } else {
      cOutput.enable();
    }
  }
  
  if (false) { // DEBUG
    writeComment("Polar mode = " + usePolarMode);
    writeComment("Live tool mode " + getLiveToolingMode(currentSection));
    writeComment("XZC mode = " + useXZCMode);
    writeComment("axial center drilling = " + axialCenterDrilling);
    writeComment("Stock transfer = " + stockTransfer);
    writeComment("Tapping = " + tapping);
  }
  
  writeln("");
  
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }
  
  if (properties.showNotes && hasParameter("notes")) {
    var notes = getParameter("notes");
    if (notes) {
      var lines = String(notes).split("\n");
      var r1 = new RegExp("^[\\s]+", "g");
      var r2 = new RegExp("[\\s]+$", "g");
      for (line in lines) {
        var comment = lines[line].replace(r1, "").replace(r2, "");
        if (comment) {
          writeComment(comment);
        }
      }
    }
  }

  if (stockTransfer) {
    return; // skip onSection(), continue in onCycle()
  }
  
  if (insertToolCall) {
    forceWorkPlane();
    cAxisModalFormat.reset();
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);
  
    if (!isFirstSection() && properties.optionalStop) {
      onCommand(COMMAND_OPTIONAL_STOP);
    }
    
    /** Handle multiple turrets. */
    if (gotMultiTurret) { 
      var activeTurret = tool.turret;
      if (activeTurret == 0) {
        warning(localize("Turret has not been specified. Using Turret 1 as default."));
        activeTurret = 1; // upper turret as default
      }
      switch (activeTurret) {
      case 1:
        // add specific handling for turret 1
        break;
      case 2:
        // add specific handling for turret 2, normally X-axis is reversed for the lower turret
        //xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:-1}); // inverted diameter mode
        //xOutput = createVariable({prefix:"X"}, xFormat);
        break;
      default:
        error(localize("Turret is not supported."));
      }
    }

    if (tool.number > 99) {
      warning(localize("Tool number exceeds maximum value."));
    }

    var compensationOffset = tool.isTurningTool() ? tool.compensationOffset : tool.lengthOffset;
    if (compensationOffset > 99) {
      error(localize("Compensation offset is out of range."));
      return;
    }
    
    if (gotSecondarySpindle) {
      switch (currentSection.spindle) {
      case SPINDLE_PRIMARY: // main spindle
        writeBlock(gSpindleModal.format(15));
        break;
      case SPINDLE_SECONDARY: // sub spindle
        writeBlock(gSpindleModal.format(14));
        break;
      }
    }

    writeBlock("T" + toolFormat.format(tool.number * 100 + compensationOffset));
    if (tool.comment) {
      writeComment(tool.comment);
    }

    var showToolZMin = false;
    if (showToolZMin && (currentSection.getType() == TYPE_MILLING)) {
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

/*
    if (properties.preloadTool) {
      var nextTool = getNextTool(tool.number);
      if (nextTool) {
        var compensationOffset = nextTool.isTurningTool() ? nextTool.compensationOffset : nextTool.lengthOffset;
        if (compensationOffset > 99) {
          error(localize("Compensation offset is out of range."));
          return;
        }
        writeBlock("T" + toolFormat.format(nextTool.number * 100 + compensationOffset));
      } else {
        // preload first tool
        var section = getSection(0);
        var firstTool = section.getTool().number;
        if (tool.number != firstTool.number) {
          var compensationOffset = firstTool.isTurningTool() ? firstTool.compensationOffset : firstTool.lengthOffset;
          if (compensationOffset > 99) {
            error(localize("Compensation offset is out of range."));
            return;
          }
          writeBlock("T" + toolFormat.format(firstTool.number * 100 + compensationOffset));
        }
      }
    }
*/
  }

  // command stop for manual tool change, useful for quick change live tools
  if (insertToolCall && tool.manualToolChange) {
    onCommand(COMMAND_STOP);
    writeBlock("(" + "MANUAL TOOL CHANGE TO T" + toolFormat.format(tool.number * 100 + compensationOffset) + ")");
  }

  if (newSpindle) {
    // select spindle if required
  }

  if ((tool.maximumSpindleSpeed > 0) && (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED)) {
    var maximumSpindleSpeed = (tool.maximumSpindleSpeed > 0) ? Math.min(tool.maximumSpindleSpeed, properties.maximumSpindleSpeed) : properties.maximumSpindleSpeed;
    writeBlock(gFormat.format(50), sOutput.format(maximumSpindleSpeed)); 
  }
  
  // see page 138 in 96-8700an for stock transfer / G199/G198 
  if (insertToolCall ||
      newSpindle ||
      isFirstSection() ||
      (rpmFormat.areDifferent(tool.spindleRPM, sOutput.getCurrent())) ||
      (tool.clockwise != getPreviousSection().getTool().clockwise)) {
    if (turning) {
      if (tool.spindleRPM > 99999) {
        warning(localize("Spindle speed exceeds maximum value."));
      }
    } else {
      if (tool.spindleRPM > 6000) {
        warning(localize("Spindle speed exceeds maximum value."));
      }
    }
    gFeedModeModal.reset();
    if (currentSection.feedMode == FEED_PER_REVOLUTION) {
      writeBlock(gFeedModeModal.format(getCode("FEED_MODE_MM_REV"))); // mm/rev
    } else {
      writeBlock(gFeedModeModal.format(getCode("FEED_MODE_MM_MIN"))); // mm/min
    }
    switch (currentSection.spindle) {
    case SPINDLE_PRIMARY: // main spindle
      if (turning || axialCenterDrilling) { // turning main spindle
        if (properties.useTailStock) {
          writeBlock(mFormat.format(currentSection.tailstock ? getCode("TAILSTOCK_ON") : getCode("TAILSTOCK_OFF")));
        }
        gSpindleModeModal.reset();
        if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
          // When Setting 9 is set to INCH, the S value specifies Surface Feet Per Minute. When Setting 9 is set to MM, the S value specifies Surface Meters Per Minute.
          writeBlock(gSpindleModeModal.format(getCode("CONSTANT_SURFACE_SPEED_ON")),
            sOutput.format(tool.surfaceSpeed * ((unit == MM) ? 1/1000.0 : 1/12.0)),
            mFormat.format(tool.clockwise ? getCode("START_MAIN_SPINDLE_CW") : getCode("START_MAIN_SPINDLE_CCW"))
          );
        } else {
          writeBlock(
            gSpindleModeModal.format(getCode("CONSTANT_SURFACE_SPEED_OFF")),
            sOutput.format(tool.spindleRPM),
            mFormat.format(tool.clockwise ? getCode("START_MAIN_SPINDLE_CW") : getCode("START_MAIN_SPINDLE_CCW"))
          );
        }
        // wait for spindle here if required
      } else { // milling main spindle
        writeBlock(
          (tapping ? sOutput.format(tool.spindleRPM) : pOutput.format(tool.spindleRPM)),
          conditional(!tapping, mFormat.format(tool.clockwise ? getCode("START_LIVE_TOOL_CW") : getCode("START_LIVE_TOOL_CCW")))
        );
      }
      break;
    case SPINDLE_SECONDARY: // sub spindle
      if (!gotSecondarySpindle) {
        error(localize("Secondary spindle is not available."));
        return;
      }
      if (turning || axialCenterDrilling) { // turning sub spindle
        // use could also swap spindles using G14/G15
        
        if (properties.useTailStock && currentSection.tailstock) {
          error(localize("Tail stock is not supported for secondary spindle."));
          return;
        }
        gSpindleModeModal.reset();
        if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
          writeBlock(
            gSpindleModeModal.format(getCode("CONSTANT_SURFACE_SPEED_ON")), 
            sOutput.format(tool.surfaceSpeed * ((unit == MM) ? 1/1000.0 : 1/12.0)),
            mFormat.format(tool.clockwise ? getCode("START_SUB_SPINDLE_CW") : getCode("START_SUB_SPINDLE_CCW"))
          );
        } else {
          writeBlock(
            gSpindleModeModal.format(getCode("CONSTANT_SURFACE_SPEED_OFF")), 
            sOutput.format(tool.spindleRPM), 
            mFormat.format(tool.clockwise ? getCode("START_SUB_SPINDLE_CW") : getCode("START_SUB_SPINDLE_CCW"))
          );
        }
        // wait for spindle here if required
      } else { // milling sub spindle
        writeBlock(
          pOutput.format(tool.spindleRPM), mFormat.format(tool.clockwise ? getCode("START_LIVE_TOOL_CW") : getCode("START_LIVE_TOOL_CCW"))
        );
      }
      break;
    }
  }

  // wcs
  if (insertToolCall) { // force work offset when changing tool
    currentWorkOffset = undefined;
  }
  var workOffset = currentSection.workOffset;
  if (workOffset == 0) {
    warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
    workOffset = 1;
  }
  if (workOffset > 0) {
    if (workOffset > 6) {
      // alternatively use G154 P1-99
      var code = workOffset - 6;
      if (code >= 26) {
        error(localize("Work offset out of range."));
        return;
      }
      if (workOffset != currentWorkOffset) {
        forceWorkPlane();
        writeBlock(gFormat.format(110 + code)); // G110->G129
        currentWorkOffset = workOffset;
      }
    } else {
      if (workOffset != currentWorkOffset) {
        forceWorkPlane();
        writeBlock(gFormat.format(53 + workOffset)); // G54->G59
        currentWorkOffset = workOffset;
      }
    }
  }

  // set coolant after we have positioned at Z
  setCoolant(tool.coolant);
  
  if (properties.gotPartCatcher) {
    engagePartCatcher(true);
  }
  
  forceAny();
  gMotionModal.reset();

  if (gotCAxis && (getLiveToolingMode(currentSection) >= 0)) {
    if (!axialCenterDrilling) {
      writeBlock(cAxisModalFormat.format(getCode("ENABLE_C_AXIS")));
    }
    gFeedModeModal.reset();
    writeBlock(tapping? gFeedModeModal.format(99) : gFeedModeModal.format(98));
  }

  var abc;
  if (currentSection.getType() == TYPE_TURNING) {
    // add support for tool indexing
    writeBlock(gPlaneModal.format(18));
    setRotation(currentSection.workPlane);
  } else if (!currentSection.isMultiAxis() && isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
    writeBlock(gPlaneModal.format(17));
    if (gotCAxis) {
      //writeBlock(gMotionModal.format(0), gFormat.format(28), "H" + abcFormat.format(0)); // unwind c-axis
    }
    writeComment("Milling from Z+ G17");
    setRotation(currentSection.workPlane);
  } else if (!currentSection.isMultiAxis() && isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
    writeBlock(gPlaneModal.format(17));
    writeComment("Milling from Z- G17");
    setRotation(currentSection.workPlane);
  } else if (machineConfigurationXC || machineConfigurationXB || machineConfiguration.isMultiAxisConfiguration()) { // use 5-axis indexing for multi-axis mode
    writeBlock(gPlaneModal.format(19));
    writeComment("Milling from X+ G19");
    // park sub spindle so there is room for milling from X+

    if (currentSection.isMultiAxis()) {
      forceWorkPlane();
      cancelTransformation();
      onCommand(COMMAND_UNLOCK_MULTI_AXIS);
    } else {
      abc = getWorkPlaneMachineABC(currentSection.workPlane);
      setWorkPlane(abc);
    }
  } else { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported by the CNC machine."));
      return;
    }
    setRotation(remaining);
  }
  forceAny();
  if (abc !== undefined) {
    cOutput.format(abc.z); // make C current - we do not want to output here
  }
  gMotionModal.reset();

  var initialPosition = getFramePosition(currentSection.getInitialPosition());
/*
  if (!retracted) {
    // TAG: need to retract along X or Z
    if (getCurrentPosition().z < initialPosition.z) {
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
    }
  }
*/
  if (usePolarMode) {
    setPolarMode(true); // enable polar interpolation mode
    onCommand(COMMAND_UNLOCK_MULTI_AXIS);
  }
  
  if (insertToolCall || retracted) {
    gPlaneModal.reset();
    gMotionModal.reset();
    if (useXZCMode) {
      writeBlock(gPlaneModal.format(17));
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      writeBlock(
        gMotionModal.format(0),
        xOutput.format(getModulus(initialPosition.x, initialPosition.y)),
        conditional(gotYAxis, yOutput.format(0)),
        cOutput.format(getC(initialPosition.x, initialPosition.y))
      );
    } else {  
      writeBlock(gMotionModal.format(0), zOutput.format(initialPosition.z));
      writeBlock(gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y));
    }
  }

  if (properties.useParametricFeed &&
      hasParameter("operation-strategy") &&
      (getParameter("operation-strategy") != "drill") && (currentSection.getType() != TYPE_TURNING)) {
    if (!insertToolCall &&
        activeMovements &&
        (getCurrentSectionId() > 0) &&
        (getPreviousSection().getPatternId() == currentSection.getPatternId())) {
      // use the current feeds
    } else {
      initializeActiveFeeds();
    }
  } else {
    activeMovements = undefined;
  }
}

/** Returns true if the toolpath fits within the machine XY limits for the given C orientation. */
function doesToolpathFitInXYRange(abc) {
  var c = 0;
  if (abc) {
    c = abc.z;
  }

  var dx = new Vector(Math.cos(c), Math.sin(c), 0);
  var dy = new Vector(Math.cos(c + Math.PI/2), Math.sin(c + Math.PI/2), 0);
  
  var xRange = currentSection.getGlobalRange(dx);
  var yRange = currentSection.getGlobalRange(dy);

  if (false) { // DEBUG    
    writeComment("toolpath X min: " + xFormat.format(xRange[0]) + ", " + "Limit " + xFormat.format(xAxisMinimum));
    writeComment("X-min within range: " + (xFormat.getResultingValue(xRange[0]) >= xFormat.getResultingValue(xAxisMinimum)));
    writeComment("toolpath Y min: " + spatialFormat.getResultingValue(yRange[0]) + ", " + "Limit " + yAxisMinimum);
    writeComment("Y-min within range: " + (spatialFormat.getResultingValue(yRange[0]) >= yAxisMinimum));
    writeComment("toolpath Y max: " + (spatialFormat.getResultingValue(yRange[1]) + ", " + "Limit " + yAxisMaximum));
    writeComment("Y-max within range: " + (spatialFormat.getResultingValue(yRange[1]) <= yAxisMaximum));
  }    
  
  if ((xFormat.getResultingValue(xRange[0]) >= xFormat.getResultingValue(xAxisMinimum)) &&
      (spatialFormat.getResultingValue(yRange[0]) >= yAxisMinimum) &&
      (spatialFormat.getResultingValue(yRange[1]) <= yAxisMaximum)) {
    return true; // toolpath does fit in XY range
  } else {
    return false; // toolpath does not fit in XY range
  }
}

function setPolarMode(activate) {
  if (activate) {
    writeBlock(gMotionModal.format(0), cOutput.format(0)); // set C-axis to 0 to avoid G112 issues
    writeBlock(gPolarModal.format(getCode("POLAR_INTERPOLATION_ON"))); // command for polar interpolation
    writeBlock(gPlaneModal.format(17));
    xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:1}); // radius mode
    xOutput = createVariable({prefix:"X"}, xFormat);
    yOutput.enable(); // required for G112
  } else {
    writeBlock(gPolarModal.format(getCode("POLAR_INTERPOLATION_OFF")));
    xFormat = createFormat({decimals:(unit == MM ? 3 : 4), forceDecimal:true, scale:2}); // diameter mode
    xOutput = createVariable({prefix:"X"}, xFormat);
    if (!gotYAxis) {
      yOutput.disable();
    }
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  milliseconds = clamp(1, seconds * 1000, 99999999);
  writeBlock(gFormat.format(4), "P" + milliFormat.format(milliseconds));
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var resetFeed = false;

function getHighfeedrate(radius) {
  if (currentSection.feedMode == FEED_PER_REVOLUTION) {
    if (toDeg(radius) <= 0) {
      radius = toPreciseUnit(0.1, MM);
    }
    var rpm = tool.spindleRPM; // rev/min
    if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      var O = 2 * Math.PI * radius; // in/rev
      rpm = tool.surfaceSpeed/O; // in/min div in/rev => rev/min
    }
    return highFeedrate/rpm; // in/min div rev/min => in/rev
  }
  return highFeedrate;
}

function onRapid(_x, _y, _z) {
  if (useXZCMode) {
    var start = getCurrentPosition();
    var dxy = getModulus(_x - start.x, _y - start.y);
    if (true || (dxy < getTolerance())) {
      var x = xOutput.format(getModulus(_x, _y));
      var c = cOutput.format(getCClosest(_x, _y, cOutput.getCurrent()));
      var z = zOutput.format(_z);
      if (pendingRadiusCompensation >= 0) {
        error(localize("Radius compensation mode cannot be changed at rapid traversal."));
        return;
      }
      writeBlock(gMotionModal.format(0), x, c, z);
      forceFeed();
      return;
    }
  
    onLinear(_x, _y, _z, highFeedrate);
    return;
  }

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  if (x || y || z) {
    var useG1 = ((x ? 1 : 0) + (y ? 1 : 0) + (z ? 1 : 0)) > 1;
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      if (useG1) {
        switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(gMotionModal.format(1), gFormat.format(41), x, y, z, getFeed(getHighfeedrate(_x)));
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(gMotionModal.format(1), gFormat.format(42), x, y, z, getFeed(getHighfeedrate(_x)));
          break;
        default:
          writeBlock(gMotionModal.format(1), gFormat.format(40), x, y, z, getFeed(getHighfeedrate(_x)));
        }
      } else {
        switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(gMotionModal.format(0), gFormat.format(41), x, y, z);
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(gMotionModal.format(0), gFormat.format(42), x, y, z);
          break;
        default:
          writeBlock(gMotionModal.format(0), gFormat.format(40), x, y, z);
        }
      }
    }
    if (false) {
      // axes are not synchronized
      writeBlock(gMotionModal.format(1), x, y, z, getFeed(getHighfeedrate(_x)));
      resetFeed = false;
    } else {
      writeBlock(gMotionModal.format(0), x, y, z);
      // forceFeed();
    }
  }
}

function onLinear(_x, _y, _z, feed) {
  if (useXZCMode) {
    if (pendingRadiusCompensation >= 0) {
      error(localize("Radius compensation is not supported."));
      return;
    }

    var start = getCurrentPosition();
    var startRadius = getModulus(start.x, start.y);
    var endRadius = getModulus(_x, _y);
    var radius = Math.min(startRadius, endRadius);
    if (false && !xFormat.areDifferent(startRadius, endRadius)) { // TAG: need to check DX/DY also
      var x = xOutput.format(endRadius);
      var z = zOutput.format(_z);
      if (xFormat.isSignificant(endRadius)) {
        var c = cOutput.format(getCClosest(_x, _y, cOutput.getCurrent()));
        writeBlock(gMotionModal.format(1), x, c, z, getFeed(feed));
      } else {
        writeBlock(gMotionModal.format(1), x, z, getFeed(feed)); // keep C
      }
      return;
    }
    if ((radius < 0.1) &&
        hasParameter("operation-strategy") &&
        (getParameter("operation-strategy") != "drill")) { // TAG: how should we handle small radii
      error(localize("Cannot machine radius 0."));
      return;
    }

    var c = getCClosest(_x, _y, cOutput.getCurrent());
    var sweep = Math.abs(c - cOutput.getCurrent());
    if (sweep >= (Math.PI - 1e-6)) {
      error(localize("Cannot machine 180deg sweep."));
      return;
    }
  
    var numberOfSegments = getNumberOfSegments(radius, sweep, getTolerance());
    // writeComment("onLinear(): C-sweep:" + abcFormat.format(sweep) + " #segments:" + numberOfSegments);
    var factor = 1.0/numberOfSegments;
    for (var i = 1; i <= numberOfSegments; ++i) {
      var u = i * factor;
      var ux = u * _x + (1 - u) * start.x;
      var uy = u * _y + (1 - u) * start.y;
      var uz = u * _z + (1 - u) * start.z;
      var x = xOutput.format(getModulus(ux, uy));
      var c = cOutput.format(getCClosest(ux, uy, cOutput.getCurrent()));
      var z = zOutput.format(uz);
      writeBlock(gMotionModal.format(1), x, c, z, getFeed(feed));
    }
    return;
  }

  if (isSpeedFeedSynchronizationActive()) {
    resetFeed = true;
    var threadPitch = getParameter("operation:threadPitch");
    var threadsPerInch = 1.0/threadPitch; // per mm for metric
    writeBlock(gMotionModal.format(32), xOutput.format(_x), yOutput.format(_y), zOutput.format(_z), pitchOutput.format(1/threadsPerInch));
    return;
  }
  if (resetFeed) {
    resetFeed = false;
    forceFeed();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var z = zOutput.format(_z);
  var f = getFeed(feed);
  if (x || y || z) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      if (currentSection.getType() == TYPE_TURNING) {
        writeBlock(gPlaneModal.format(18));
      } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
        writeBlock(gPlaneModal.format(17));
      } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
        writeBlock(gPlaneModal.format(19));
      } else {
        error(localize("Tool orientation is not supported for radius compensation."));
        return;
      }
      switch (radiusCompensation) {
      case RADIUS_COMPENSATION_LEFT:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(41), x, y, z, f);
        break;
      case RADIUS_COMPENSATION_RIGHT:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(42), x, y, z, f);
        break;
      default:
        writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), gFormat.format(40), x, y, z, f);
      }
    } else {
      writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), x, y, z, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(isSpeedFeedSynchronizationActive() ? 32 : 1), f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("Multi-axis motion is not supported for XZC mode."));
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
  if (true) {
    // axes are not synchronized
    writeBlock(gMotionModal.format(1), x, y, z, a, b, c, getFeed(highFeedrate));
  } else {
    writeBlock(gMotionModal.format(0), x, y, z, a, b, c);
    forceFeed();
  }
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  if (!currentSection.isOptimizedForMachine()) {
    error(localize("Multi-axis motion is not supported for XZC mode."));
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
  var f = getFeed(feed);

  if (x || y || z || a || b || c) {
    writeBlock(gMotionModal.format(1), x, y, z, a, b, c, f);
  } else if (f) {
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      forceFeed(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (useXZCMode) {
    // TAG: var numberOfSegments = toDeg(getCircularSweep())/120;

    switch (getCircularPlane()) {
    case PLANE_ZX:
      if (!isSpiral()) {
        var c = getCClosest(x, y, cOutput.getCurrent());
        if (!cFormat.areDifferent(c, cOutput.getCurrent())) {
          validate(getCircularSweep() < Math.PI, localize("Circular sweep exceeds limit."));
          var start = getCurrentPosition();
          writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(getModulus(x, y)), cOutput.format(c), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
          return;
        }
      }
      break;
    case PLANE_XY:
      var d2 = center.x * center.x + center.y * center.y;
      if (d2 < 1e-18) { // center is on rotary axis
        writeBlock(gMotionModal.format(1), xOutput.format(getModulus(x, y)), cOutput.format(getCClosest(x, y, cOutput.getCurrent(), clockwise)), zOutput.format(z), getFeed(feed));
        return;
      }
      break;
    }
    
    linearize(getTolerance());
    return;
  }

  if (isSpeedFeedSynchronizationActive()) {
    error(localize("Speed-feed synchronization is not supported for circular moves."));
    return;
  }
  
  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
    return;
  }

  var start = getCurrentPosition();

  if (isFullCircle()) {
    if (properties.useRadius || isHelical()) { // radius mode does not support full arcs
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), getFeed(feed));
      break;
    case PLANE_ZX:
       if (usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    case PLANE_YZ:
      if (usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else if (!properties.useRadius) {
    if (isHelical() && ((getCircularSweep() < toRad(30)) || (getHelicalPitch() > 10))) { // avoid G112 issue
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      if (!xFormat.isSignificant(start.x) && usePolarMode) {
        writeBlock(gMotionModal.format(1), xOutput.format((unit == IN) ? 0.0001 : 0.001), getFeed(feed)); // move X to non zero to avoid G112 issues
      }
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), getFeed(feed));
      break;
    case PLANE_ZX:
      if (usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), iOutput.format(cx - start.x, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    case PLANE_YZ:
      if (usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), jOutput.format(cy - start.y, 0), kOutput.format(cz - start.z, 0), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else { // use radius mode
    if (isHelical() && ((getCircularSweep() < toRad(30)) || (getHelicalPitch() > 10))) {
      linearize(tolerance);
      return;
    }
    var r = getCircularRadius();
    if (toDeg(getCircularSweep()) > (180 + 1e-9)) {
      r = -r; // allow up to <360 deg arcs
    }
    switch (getCircularPlane()) {
    case PLANE_XY:
      if ((spatialFormat.format(start.x) == 0) && usePolarMode) {
        writeBlock(gMotionModal.format(1), xOutput.format((unit == IN) ? 0.0001 : 0.001), getFeed(feed)); // move X to non zero to avoid G112 issues
      }
      writeBlock(gPlaneModal.format(17), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_ZX:
      if (usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(18), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    case PLANE_YZ:
      if (usePolarMode) {
        linearize(tolerance);
        return;
      }
      writeBlock(gPlaneModal.format(19), gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), zOutput.format(z), "R" + rFormat.format(r), getFeed(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

function onCycle() {
  if (cycleType == "stock-transfer") {
    error(localize("Stock transfer is not supported. Required machine specific customization."));
    return;

/*
    writeBlock(mFormat.format(getCode("STOP_MAIN_SPINDLE")));
    setCoolant(COOLANT_OFF);
    onCommand(COMMAND_OPTIONAL_STOP);
    
    // wcs required here
    var workOffset = currentSection.workOffset;
    if (workOffset == 0) {
      warningOnce(localize("Work offset has not been specified. Using G54 as WCS."), WARNING_WORK_OFFSET);
      workOffset = 1;
    }
    if (workOffset > 0) {
      if (workOffset > 6) {
        // alternatively use G154 P1-99
        var code = workOffset - 6;
        if (code >= 26) {
          error(localize("Work offset out of range."));
          return;
        }
        if (workOffset != currentWorkOffset) {
          forceWorkPlane();
          writeBlock(gFormat.format(110 + code)); // G110->G129
          currentWorkOffset = workOffset;
        }
      } else {
        if (workOffset != currentWorkOffset) {
          forceWorkPlane();
          writeBlock(gFormat.format(53 + workOffset)); // G54->G59
          currentWorkOffset = workOffset;
        }
      }
    }
    
    gMotionModal.reset();
    gFeedModeModal.reset();
    writeBlock(gFormat.format(103), "P1"); // Look Ahead set to 1 block
    writeBlock(mFormat.format(getCode("UNCLAMP_SECONDARY_CHUCK")));
    writeBlock(gFeedModeModal.format(98));
    writeBlock(gMotionModal.format(0), "B" + zFormat.format(properties.transBClearance));
    writeBlock(mFormat.format(12)); //Sub Spindle Air Blow on
    writeBlock(gMotionModal.format(1), "B" + zFormat.format(properties.transBPosition), "F" + feedFormat.format(properties.transFeedrate)); // move subspindle to main spindle with safety distance
    writeBlock(mFormat.format(getCode("CLAMP_SECONDARY_CHUCK")));
    onDwell(1);
    writeBlock(mFormat.format(getCode("UNCLAMP_PRIMARY_CHUCK")));
    onDwell(1);
    writeBlock(gMotionModal.format(1), "B" + zFormat.format(properties.transBClearance), "F" + feedFormat.format(properties.transFeedrate)); 
    writeBlock(mFormat.format(13)); //Sub Spindle Air Blow off
    writeBlock(gMotionModal.format(0), "B" + zFormat.format(0));
    writeBlock(mFormat.format(getCode("CLAMP_PRIMARY_CHUCK")));
    writeBlock(gFormat.format(103)); // Look Ahead set to Default
    gMotionModal.reset();
    gFeedModeModal.reset();
*/
  }
}

function getCommonCycle(x, y, z, r) {
  // forceXYZ(); // force xyz on first drill hole of any cycle
  if (useXZCMode) {
    cOutput.reset();
    return [xOutput.format(getModulus(x, y)), cOutput.format(getCClosest(x, y, cOutput.getCurrent())),
      zOutput.format(z),
      conditional(r !== undefined, "R" + spatialFormat.format(gPlaneModal.getCurrent() == 19 ? r*2 : r))];
  } else {
    return [xOutput.format(x), yOutput.format(y),
      zOutput.format(z),
      conditional(r !== undefined, "R" + spatialFormat.format(gPlaneModal.getCurrent() == 19 ? r*2 : r))];
  }
}

function writeCycleClearance() {
  if (true) {
    switch (gPlaneModal.getCurrent()) {
    case 17:
      writeBlock(gMotionModal.format(0), zOutput.format(cycle.clearance));
      break;
    case 18:
      writeBlock(gMotionModal.format(0), yOutput.format(cycle.clearance));
      break;
    case 19:
      writeBlock(gMotionModal.format(0), xOutput.format(cycle.clearance));
      break;
    default:
      error(localize("Unsupported drilling orientation."));
      return;
    }
  }
}

function onCyclePoint(x, y, z) {

  if (!properties.useCycles || currentSection.isMultiAxis()) {
    expandCyclePoint(x, y, z);
    return;
  }

  if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1)) ||
      isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
    writeBlock(gPlaneModal.format(17)); // XY plane
  } else if (Vector.dot(currentSection.workPlane.forward, new Vector(0, 0, 1)) < 1e-7) {
    writeBlock(gPlaneModal.format(19)); // YZ plane
  } else {
    expandCyclePoint(x, y, z);
    return;
  }

  switch (cycleType) {
  case "thread-turning":
    var i = -cycle.incrementalX; // positive if taper goes down - delta radius
    var threadsPerInch = 1.0/cycle.pitch; // per mm for metric
    var f = 1/threadsPerInch;
    writeBlock(gMotionModal.format(92), xOutput.format(x - cycle.incrementalX), yOutput.format(y), zOutput.format(z), conditional(zFormat.isSignificant(i), g92IOutput.format(i)), pitchOutput.format(f));
    forceFeed();
    return;
  }

  if (true) {
    // repositionToCycleClearance(cycle, x, y, z);
    // return to initial Z which is clearance plane and set absolute mode
    feedOutput.reset();

    var F = (gFeedModeModal.getCurrent() == 99 ? cycle.feedrate/tool.spindleRPM : cycle.feedrate);
    var P = (cycle.dwell == 0) ? 0 : clamp(1, cycle.dwell * 1000, 99999999); // in milliseconds

    switch (cycleType) {
    case "drilling":
      forceXYZ();
      writeCycleClearance();
      writeBlock(
        gCycleModal.format(gPlaneModal.getCurrent() == 19 ? 241 : 81),
        getCommonCycle(x, y, z, cycle.retract),
        feedOutput.format(F)
      );
      break;
    case "counter-boring":
      writeCycleClearance();
      forceXYZ();
      if (P > 0) {
        writeBlock(
          gCycleModal.format(gPlaneModal.getCurrent() == 19 ? 242 : 82),
          getCommonCycle(x, y, z, cycle.retract),
          "P" + milliFormat.format(P),
          feedOutput.format(F)
        );
      } else {
        writeBlock(
          gCycleModal.format(gPlaneModal.getCurrent() == 19 ? 241 : 81),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "chip-breaking":
    case "deep-drilling":
      writeCycleClearance();
      forceXYZ();
      writeBlock(
        gCycleModal.format(gPlaneModal.getCurrent() == 19 ? 243 : 83),
        getCommonCycle(x, y, z, cycle.retract),
        "Q" + spatialFormat.format(cycle.incrementalDepth), //lathe prefers single Q peck value, IJK causes error   
        //"I" + spatialFormat.format(cycle.incrementalDepth),
        //"J" + spatialFormat.format(cycle.incrementalDepthReduction),
        //"K" + spatialFormat.format(cycle.minimumIncrementalDepth),
        conditional(P > 0, "P" + milliFormat.format(P)),
        feedOutput.format(F)
      );
      break;
    case "tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeCycleClearance();
      if (gPlaneModal.getCurrent() == 19) {
        xOutput.reset();
        writeBlock(gMotionModal.format(0), zOutput.format(z), yOutput.format(y));
        writeBlock(gMotionModal.format(0), xOutput.format(cycle.retract));
        writeBlock(
          gCycleModal.format((tool.type == TOOL_TAP_LEFT_HAND) ? 196 : 195),
          getCommonCycle(x, y, z, undefined),
          pitchOutput.format(F)
        );
      } else {
        forceXYZ();
        writeBlock(
          gCycleModal.format((tool.type == TOOL_TAP_LEFT_HAND) ? 186 : 95),
          getCommonCycle(x, y, z, cycle.retract),
          pitchOutput.format(F)
        );
      }
      forceFeed();
      break;
    case "left-tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeCycleClearance();
      xOutput.reset();
      if (gPlaneModal.getCurrent() == 19) {
        writeBlock(gMotionModal.format(0), zOutput.format(z), yOutput.format(y));
        writeBlock(gMotionModal.format(0), xOutput.format(cycle.retract));
      }
      writeBlock(
        gCycleModal.format((gPlaneModal.getCurrent() == 19) ? 196 : 186),
        getCommonCycle(x, y, z, (gPlaneModal.getCurrent() == 19) ? undefined : cycle.retract),
        pitchOutput.format(F)
      );
      forceFeed();
      break;
    case "right-tapping":
      if (!F) {
        F = tool.getTappingFeedrate();
      }
      writeCycleClearance();
      xOutput.reset();
      if (gPlaneModal.getCurrent() == 19) {
        writeBlock(gMotionModal.format(0), zOutput.format(z), yOutput.format(y));
        writeBlock(gMotionModal.format(0), xOutput.format(cycle.retract));
      }      
      writeBlock(
        gCycleModal.format((gPlaneModal.getCurrent() == 19) ? 195 : 84),
        getCommonCycle(x, y, z, (gPlaneModal.getCurrent() == 19) ? undefined : cycle.retract),
        pitchOutput.format(F)
      );
      forceFeed();
      break;
    case "tapping-with-chip-breaking":
    case "left-tapping-with-chip-breaking":
    case "right-tapping-with-chip-breaking":
      error(localize("Tapping with chip breaking is not supported."));
      return;
    case "fine-boring":
      expandCyclePoint(x, y, z);
      break;
    case "reaming":
      if (gPlaneModal.getCurrent() == 19) {
        expandCyclePoint(x, y, z);
      } else {
        writeCycleClearance();
        forceXYZ();
        writeBlock(
          gCycleModal.format(85),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "stop-boring":
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeCycleClearance();
        forceXYZ();
        writeBlock(
          gCycleModal.format((gPlaneModal.getCurrent() == 19) ? 246 : 86),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    case "boring":
      if (P > 0) {
        expandCyclePoint(x, y, z);
      } else {
        writeCycleClearance();
        forceXYZ();
        writeBlock(
          gCycleModal.format((gPlaneModal.getCurrent() == 19) ? 245 : 85),
          getCommonCycle(x, y, z, cycle.retract),
          feedOutput.format(F)
        );
      }
      break;
    default:
      expandCyclePoint(x, y, z);
    }
    if (!cycleExpanded) {
      writeBlock(gCycleModal.format(80));
      gMotionModal.reset();
    }
  } else {
    if (cycleExpanded) {
      expandCyclePoint(x, y, z);
    } else if (useXZCMode) {
      var _x = xOutput.format(getModulus(x, y));
      var _c = cOutput.format(getC(x, y));
      if (!_x /*&& !_y*/ && !_c) {
        xOutput.reset(); // at least one axis is required
        _x = xOutput.format(getModulus(x, y));
      }
      writeBlock(_x, _c);
    } else {
      var _x = xOutput.format(x);
      var _y = yOutput.format(y);
      var _z = zOutput.format(z);
      if (!_x && !_y && !_z) {
        switch (gPlaneModal.getCurrent()) {
        case 17: // XY
          xOutput.reset(); // at least one axis is required
          _x = xOutput.format(x);
          break;
        case 18: // ZX
          zOutput.reset(); // at least one axis is required
          _z = zOutput.format(z);
          break;
        case 19: // YZ
          yOutput.reset(); // at least one axis is required
          _y = yOutput.format(y);
          break;
        }
      }
      writeBlock(_x, _y, _z);
    }
  }
}

function onCycleEnd() {
  if (!cycleExpanded) {
    switch (cycleType) {
    case "thread-turning":
      forceFeed();
      xOutput.reset();
      zOutput.reset();
      g92IOutput.reset();
      break;
    default:
      writeBlock(gCycleModal.format(80));
      gMotionModal.reset();
    }
  }
}

function onPassThrough(text) {
  writeBlock(text);
}

function onParameter(name, value) {
}

var currentCoolantMode = COOLANT_OFF;

function setCoolant(coolant) {
  if (coolant == currentCoolantMode) {
    return; // coolant is already active
  }

  var m = undefined;
  if (coolant == COOLANT_OFF) {
    if (currentCoolantMode == COOLANT_THROUGH_TOOL) {
      m = 89;
    } else if (currentCoolantMode == COOLANT_AIR) {
      m = 84;
    } else {
      m = 9;
    }
    writeBlock(mFormat.format(m));
    currentCoolantMode = COOLANT_OFF;
    return;
  }

  if (currentCoolantMode != COOLANT_OFF) {
    setCoolant(COOLANT_OFF);
  }

  switch (coolant) {
  case COOLANT_FLOOD:
    m = 8;
    break;
  case COOLANT_THROUGH_TOOL:
    m = 88;
    break;
  case COOLANT_AIR:
    m = 83;
    break;
  default:
    warning(localize("Coolant not supported."));
    if (currentCoolantMode == COOLANT_OFF) {
      return;
    }
    coolant = COOLANT_OFF;
    m = 9;
  }

  writeBlock(mFormat.format(m));
  currentCoolantMode = coolant;
}

function onCommand(command) {
  switch (command) {
  case COMMAND_COOLANT_OFF:
    setCoolant(COOLANT_OFF);
    break;
  case COMMAND_COOLANT_ON:
    setCoolant(COOLANT_FLOOD);
    break;
  case COMMAND_LOCK_MULTI_AXIS:
    writeBlock(mFormat.format((currentSection.getSpindle() == 0) ? 14 : 114));
    break;
  case COMMAND_UNLOCK_MULTI_AXIS:
    writeBlock(mFormat.format((currentSection.getSpindle() == 0) ? 15 : 115));
    break;
  case COMMAND_START_CHIP_TRANSPORT:
    writeBlock(mFormat.format(31));
    break;
  case COMMAND_STOP_CHIP_TRANSPORT:
    writeBlock(mFormat.format(33));
    break;
  case COMMAND_OPEN_DOOR:
    if (gotDoorControl) {
      writeBlock(mFormat.format(85)); // optional
    }
    break;
  case COMMAND_CLOSE_DOOR:
    if (gotDoorControl) {
      writeBlock(mFormat.format(86)); // optional
    }
    break;
  case COMMAND_BREAK_CONTROL:
    break;
  case COMMAND_TOOL_MEASURE:
    break;
  case COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION:
    break;
  case COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION:
    break;
  case COMMAND_STOP:
    writeBlock(mFormat.format(0));
    forceSpindleSpeed = true;
    break;
  case COMMAND_OPTIONAL_STOP:
    writeBlock(mFormat.format(1));
    break;
  case COMMAND_END:
    writeBlock(mFormat.format(2));
    break;
  case COMMAND_ORIENTATE_SPINDLE:
    if (currentSection.getType() == TYPE_TURNING) {
      if (getSpindle() == 0) {
        writeBlock(mFormat.format(19)); // use P or R to set angle (optional)
      } else {
        writeBlock(mFormat.format(119));
      }
    } else {
      if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
        writeBlock(mFormat.format(19)); // use P or R to set angle (optional)
      } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
        writeBlock(mFormat.format(119));
      } else {
        error(localize("Spindle orientation is not supported for live tooling."));
        return;
      }
    }
    break;
  //case COMMAND_CLAMP: // add support for clamping
  //case COMMAND_UNCLAMP: // add support for clamping
  default:
    onUnsupportedCommand(command);
  }
}

function getCode(code) {
  switch(code) {
  case "PART_CATCHER_ON":
    return 36; 
  case "PART_CATCHER_OFF":
    return 37; 
  case "TAILSTOCK_ON":
    return 21;
  case "TAILSTOCK_OFF":
    return 22;
  case "ENABLE_C_AXIS":
    return 154;
  case "DISABLE_C_AXIS":
    return 155;
  case "POLAR_INTERPOLATION_ON":
    return 112;
  case "POLAR_INTERPOLATION_OFF":
    return 113;
  case "STOP_LIVE_TOOL":
    return 135;
  case "STOP_MAIN_SPINDLE":
    return 5;
  case "STOP_SUB_SPINDLE_CW":
    return 5;
  case "START_LIVE_TOOL_CW":
    return 133;
  case "START_LIVE_TOOL_CCW":
    return 134;
  case "START_MAIN_SPINDLE_CW":
    return 3;
  case "START_MAIN_SPINDLE_CCW":
    return 4;
  case "START_SUB_SPINDLE_CW":
    return 3;
  case "START_SUB_SPINDLE_CCW":
    return 4;
  case "FEED_MODE_MM_REV":
    return 99;
  case "FEED_MODE_MM_MIN":
    return 98;
  case "CONSTANT_SURFACE_SPEED_ON":
    return 96;
  case "CONSTANT_SURFACE_SPEED_OFF":
    return 97;
  case "AUTO_AIR_ON":
    return 12;
  case "AUTO_AIR_OFF":
    return 13;
  case "CLAMP_PRIMARY_CHUCK":
    return 10;
  case "UNCLAMP_PRIMARY_CHUCK":
    return 11;
  case "CLAMP_SECONDARY_CHUCK":
    return 110;
  case "UNCLAMP_SECONDARY_CHUCK":
    return 111;
  case "SPINDLE_SYNCHRONIZATION_ON":
    return 199;
  case "SPINDLE_SYNCHRONIZATION_OFF":
    return 198;
  default:
    error(localize("Command " + code + " is not defined."));
    return 0;
  }
}

function engagePartCatcher(engage) {

  if (properties.gotPartCatcher &&
      hasParameter("operation-strategy") &&
      (getParameter("operation-strategy") == "turningPart") &&
      currentSection.partCatcher) {
    if (engage) { 
      // catch part here
      writeBlock(mFormat.format(getCode("PART_CATCHER_ON")), formatComment(localize("PART CATCHER ON")));
    } else {
      onCommand(COMMAND_COOLANT_OFF);
      writeBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(properties.G53HomePosition_X)); // retract
      writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format(currentSection.spindle == SPINDLE_SECONDARY ? properties.G53HomePositionSub_Z : properties.G53HomePosition_Z)); // retract
      writeBlock(mFormat.format(getCode("PART_CATCHER_OFF")), formatComment(localize("PART CATCHER OFF")));
      forceXYZ();
    }
  }
}

function onSectionEnd() {

  if (properties.gotPartCatcher) {
    engagePartCatcher(false);
  }
  
  if (usePolarMode) {
    setPolarMode(false); // disable polar interpolation mode
  }
  
  if (!isLastSection()) {
    if (gotCAxis && (getLiveToolingMode(getNextSection()) < 0) && !currentSection.isPatterned() && (getLiveToolingMode(currentSection) >= 0)) {
      writeBlock(cAxisModalFormat.format(getCode("DISABLE_C_AXIS")));
    }
  }
  
  if (((getCurrentSectionId() + 1) >= getNumberOfSections()) ||
      (tool.number != getNextSection().getTool().number)) {
    onCommand(COMMAND_BREAK_CONTROL);
  }

  if ((currentSection.getType() == TYPE_MILLING) &&
      (!hasNextSection() || (hasNextSection() && (getNextSection().getType() != TYPE_MILLING)))) {
    // exit milling mode
    if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, 1))) {
    } else if (isSameDirection(currentSection.workPlane.forward, new Vector(0, 0, -1))) {
    } else {
      writeBlock(mFormat.format(getCode("STOP_LIVE_TOOL"))); 
    }
  }

  forceAny();
}

function onClose() {
  writeln("");

  optionalSection = false;

  onCommand(COMMAND_COOLANT_OFF);

  if (properties.gotChipConveyor) {
    onCommand(COMMAND_STOP_CHIP_TRANSPORT);
  }
  
  if (getNumberOfSections() > 0) { // Retracting Z first causes safezone overtravel error to keep from crashing into subspindle. Z should already be retracted to and end of section.
    var section = getSection(getNumberOfSections() - 1);
    if ((section.getType() != TYPE_TURNING) && isSameDirection(section.workPlane.forward, new Vector(0, 0, 1))) {
      writeBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(properties.G53HomePosition_X), conditional(gotYAxis, "Y" + yFormat.format(properties.G53HomePosition_Y))); // retract
      xOutput.reset();
      yOutput.reset();
      writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format((currentSection.spindle == SPINDLE_SECONDARY) ? properties.G53HomePositionSub_Z : properties.G53HomePosition_Z)); // retract
      zOutput.reset();
      writeBlock(mFormat.format(getCode("STOP_LIVE_TOOL")));
    } else {
      if (gotYAxis) {
        writeBlock(gFormat.format(53), gMotionModal.format(0), "Y" + yFormat.format(properties.G53HomePosition_Y)); // retract
      }
      writeBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(properties.G53HomePosition_X)); // retract
      xOutput.reset();
      yOutput.reset();
      writeBlock(gFormat.format(53), gMotionModal.format(0), "Z" + zFormat.format(currentSection.spindle == SPINDLE_SECONDARY ? properties.G53HomePositionSub_Z : properties.G53HomePosition_Z)); // retract
      zOutput.reset();
      writeBlock(mFormat.format(getCode("STOP_MAIN_SPINDLE")));
    }
  }

  if (gotCAxis && (getLiveToolingMode(currentSection) >= 0)) {
    writeBlock(gFormat.format(28), "H" + abcFormat.format(0)); // unwind
    writeBlock(cAxisModalFormat.format(getCode("DISABLE_C_AXIS")));
  }

  if (gotYAxis) {
    writeBlock(gFormat.format(53), gMotionModal.format(0), "Y" + yFormat.format(properties.G53HomePosition_Y));
    yOutput.reset();
  }

  if (gotBarFeeder) {
    writeln("");
    writeComment(localize("Bar feed"));
    writeBlock(mFormat.format(5));
    // feed bar here
    writeOptionalBlock(gFormat.format(105));
    writeOptionalBlock(gFormat.format(53), gMotionModal.format(0), "X" + xFormat.format(properties.G53HomePosition_X));
    writeOptionalBlock(mFormat.format(1));
    writeOptionalBlock(mFormat.format(99)); // restart
  }

  writeln("");
  onImpliedCommand(COMMAND_END);
  onImpliedCommand(COMMAND_STOP_SPINDLE);
  writeBlock(mFormat.format(30)); // stop program, spindle stop, coolant off
  writeln("%");
}
