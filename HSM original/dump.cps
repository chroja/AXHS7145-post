/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  Dump configuration.

  $Revision: 40091 $
  $Date: 2015-10-14 17:29:32 +0200 (on, 14 okt 2015) $
  
  FORKID {4E9DFE89-DA1C-4531-98C9-7FECF672BD47}
*/

description = "Dumper";
vendor = "Autodesk, Inc.";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;

longDescription = "Use this post to understand which information is available when developing a new post. The post will output the primary information for each entry function being called.";

capabilities = CAPABILITY_INTERMEDIATE;
extension = "dmp";
// using user code page

allowMachineChangeOnSection = true;
allowHelicalMoves = true;
allowSpiralMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion
maximumCircularSweep = toRad(1000000);
minimumCircularRadius = spatial(0.001, MM);
maximumCircularRadius = spatial(1000000, MM);

var spatialFormat = createFormat({decimals:6});
var angularFormat = createFormat({decimals:6, scale:DEG});

function toString(value) {
  if (typeof(value) == 'string') {
    return "'" + value + "'";
  } else {
    return value;
  }
}

function dumpImpl(name, text) {
  writeln(getCurrentRecordId() + ": " + name + "(" + text + ")");  
}

function dump(name, _arguments) {
  var result = getCurrentRecordId() + ": " + name + "(";
  for (var i = 0; i < _arguments.length; ++i) {
    if (i > 0) {
      result += ", ";
    }
    if (typeof(_arguments[i]) == 'string') {
      result += "'" + _arguments[i] + "'";
    } else {
      result += _arguments[i];
    }
  }
  result += ")";
  writeln(result);  
}

function onMachine() {
  dump("onMachine", arguments);
  if (machineConfiguration.getVendor()) {
    writeln("  " + "Vendor" + ": " + machineConfiguration.getVendor());
  }
  if (machineConfiguration.getModel()) {
    writeln("  " + "Model" + ": " + machineConfiguration.getModel());
  }
  if (machineConfiguration.getDescription()) {
    writeln("  " + "Description" + ": "  + machineConfiguration.getDescription());
  }
}

function onOpen() {
  dump("onOpen", arguments);
}

function onPassThrough() {
  dump("onPassThrough", arguments);
}

function onComment() {
  dump("onComment", arguments);
}

function onSection() {
  dump("onSection", arguments);

  var name;
  for (name in currentSection) {
    value = currentSection[name];
    if (typeof(value) != 'function') {
      writeln("  currentSection." + name + "=" + toString(value));
    }
  }

  for (name in tool) {
    value = tool[name];
    if (typeof(value) != 'function') {
      writeln("  tool." + name + "=" + toString(value));
    }
  }

  {
    var shaft = tool.shaft;
    if (shaft && shaft.hasSections()) {
      var n = shaft.getNumberOfSections();
      for (var i = 0; i < n; ++i) {
        writeln("  tool.shaft[" + i + "] H=" + shaft.getLength(i) + " D=" + shaft.getDiameter(i));
      }
    }
  }

  {
    var holder = tool.holder;
    if (holder && holder.hasSections()) {
      var n = holder.getNumberOfSections();
      for (var i = 0; i < n; ++i) {
        writeln("  tool.holder[" + i + "] H=" + holder.getLength(i) + " D=" + holder.getDiameter(i));
      }
    }
  }

  if (currentSection.isPatterned && currentSection.isPatterned()) {
    var patternId = currentSection.getPatternId();
    var sections = [];
    var first = true;
    for (var i = 0; i < getNumberOfSections(); ++i) {
      var section = getSection(i);
      if (section.getPatternId() == patternId) {
        if (i < getCurrentSectionId()) {
          first = false; // not the first pattern instance
        }
        if (i != getCurrentSectionId()) {
          sections.push(section.getId());
        }
      }
    }
    writeln("  >>> Pattern instances: " + sections);
    if (!first) {
      // writeln("  SKIPPING PATTERN INSTANCE");
      // skipRemainingSection();
    }
  }
}

function onParameter() {
  dump("onParameter", arguments);
}

function onDwell() {
  dump("onDwell", arguments);
}

function onCycle() {
  dump("onCycle", arguments);

  writeln("  cycleType=" + toString(cycleType));
  for (var name in cycle) {
    value = cycle[name];
    if (typeof(value) != 'function') {
      writeln("  cycle." + name + "=" + toString(value));
    }
  }
}

function onCyclePoint() {
  dump("onCyclePoint", arguments);
}

function onCycleEnd() {
  dump("onCycleEnd", arguments);
}

/**
  Returns the string id for the specified movement. Returns the movement id as
  a string if unknown.
*/
function getMovementStringId(movement, jet) {
  switch (movement) {
  case MOVEMENT_RAPID:
    return "rapid";
  case MOVEMENT_LEAD_IN:
    return "lead in";
  case MOVEMENT_CUTTING:
    return "cutting";
  case MOVEMENT_LEAD_OUT:
    return "lead out";
  case MOVEMENT_LINK_TRANSITION:
    return !jet ? "transition" : "bridging";
  case MOVEMENT_LINK_DIRECT:
    return "direct";
  case MOVEMENT_RAMP_HELIX:
    return !jet ? "helix ramp" : "circular pierce";
  case MOVEMENT_RAMP_PROFILE:
    return !jet ? "profile ramp" : "profile pierce";
  case MOVEMENT_RAMP_ZIG_ZAG:
    return !jet ? "zigzag ramp" : "linear pierce";
  case MOVEMENT_RAMP:
    return !jet ? "ramp" : "pierce";
  case MOVEMENT_PLUNGE:
    return !jet ? "plunge" : "pierce";
  case MOVEMENT_PREDRILL:
    return "predrill";
  case MOVEMENT_EXTENDED:
    return "extended";
  case MOVEMENT_REDUCED:
    return "reduced";
  case MOVEMENT_FINISH_CUTTING:
    return "finish cut";
  case MOVEMENT_HIGH_FEED:
    return "high feed";
  default:
    return String(movement);
  }
}

function onMovement(movement) {
  var jet = tool.isJetTool && tool.isJetTool();
  var id;
  switch (movement) {
  case MOVEMENT_RAPID:
    id = "MOVEMENT_RAPID";
    break;
  case MOVEMENT_LEAD_IN:
    id = "MOVEMENT_LEAD_IN";
    break;
  case MOVEMENT_CUTTING:
    id = "MOVEMENT_CUTTING";
    break;
  case MOVEMENT_LEAD_OUT:
    id = "MOVEMENT_LEAD_OUT";
    break;
  case MOVEMENT_LINK_TRANSITION:
    id = jet ? "MOVEMENT_BRIDGING" : "MOVEMENT_LINK_TRANSITION";
    break;
  case MOVEMENT_LINK_DIRECT:
    id = "MOVEMENT_LINK_DIRECT";
    break;
  case MOVEMENT_RAMP_HELIX:
    id = jet ? "MOVEMENT_PIERCE_CIRCULAR" : "MOVEMENT_RAMP_HELIX";
    break;
  case MOVEMENT_RAMP_PROFILE:
    id = jet ? "MOVEMENT_PIERCE_PROFILE" : "MOVEMENT_RAMP_PROFILE";
    break;
  case MOVEMENT_RAMP_ZIG_ZAG:
    id = jet ? "MOVEMENT_PIERCE_LINEAR" : "MOVEMENT_RAMP_ZIG_ZAG";
    break;
  case MOVEMENT_RAMP:
    id = "MOVEMENT_RAMP";
    break;
  case MOVEMENT_PLUNGE:
    id = jet ? "MOVEMENT_PIERCE" : "MOVEMENT_PLUNGE";
    break;
  case MOVEMENT_PREDRILL:
    id = "MOVEMENT_PREDRILL";
    break;
  case MOVEMENT_EXTENDED:
    id = "MOVEMENT_EXTENDED";
    break;
  case MOVEMENT_REDUCED:
    id = "MOVEMENT_REDUCED";
    break;
  case MOVEMENT_HIGH_FEED:
    id = "MOVEMENT_HIGH_FEED";
    break;
  }
  if (id != undefined) {
    dumpImpl("onMovement", id + " /*" + getMovementStringId(movement, jet) + "*/");
  } else {
    dumpImpl("onMovement", movement + " /*" + getMovementStringId(movement, jet) + "*/");
  }
}

var RADIUS_COMPENSATION_MAP = {0:"off", 1:"left", 2:"right"};

function onRadiusCompensation() {
  var id;
  switch (radiusCompensation) {
  case RADIUS_COMPENSATION_OFF:
    id = "RADIUS_COMPENSATION_OFF";
    break;
  case RADIUS_COMPENSATION_LEFT:
    id = "RADIUS_COMPENSATION_LEFT";
    break;
  case RADIUS_COMPENSATION_RIGHT:
    id = "RADIUS_COMPENSATION_RIGHT";
    break;
  }
  dump("onRadiusCompensation", arguments);
  if (id != undefined) {
    writeln("  radiusCompensation=" + id + " // " + RADIUS_COMPENSATION_MAP[radiusCompensation]);
  } else {
    writeln("  radiusCompensation=" + radiusCompensation + " // " + RADIUS_COMPENSATION_MAP[radiusCompensation]);
  }
}

function onRapid() {
  dump("onRapid", arguments);
}

function onLinear() {
  dump("onLinear", arguments);
}

function onRapid5D() {
  dump("onRapid5D", arguments);
}

function onLinear5D() {
  dump("onLinear5D", arguments);
}

function onCircular() {
  dump("onCircular", arguments);
  writeln("  sweep: " + angularFormat.format(getCircularSweep()) + "deg");
  if (isSpiral()) {
    writeln("  spiral");
    writeln("  start radius: " + spatialFormat.format(getCircularStartRadius()));
    writeln("  end radius: " + spatialFormat.format(getCircularRadius()));
    writeln("  delta radius: " + spatialFormat.format(getCircularRadius() - getCircularStartRadius()));
  } else {
    writeln("  radius: " + spatialFormat.format(getCircularRadius()));
  }
  if (isHelical()) {
    writeln("  helical pitch: " + spatialFormat.format(getHelicalPitch()));
  }
}

function onCommand(command) {
  if (isWellKnownCommand(command)) {
    dumpImpl("onCommand", getCommandStringId(command));
  } else {
    dumpImpl("onCommand", command);
  }
}

function onSectionEnd() {
  dump("onSectionEnd", arguments);
}

function onClose() {
  dump("onClose", arguments);
}
