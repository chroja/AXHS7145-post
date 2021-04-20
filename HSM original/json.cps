/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  JavaScript Object Notation post processor configuration.

  $Revision: 40091 $
  $Date: 2015-10-14 17:29:32 +0200 (on, 14 okt 2015) $
  
  FORKID {6F22B39A-3B1F-4cc7-A048-75950D66719F}
*/

description = "JSON JavaScript Object Notation";
vendor = "Autodesk, Inc.";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;

longDescription = "Example post demonstrating how to export the program in the JSON (JavaScript Object Notation) format.";

unit = ORIGINAL_UNIT; // do not map unit
capabilities = CAPABILITY_INTERMEDIATE;
extension = "json";
setCodePage("utf-8");

properties = {
  pretty: true // include spaces in the output
};

allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

function f(value) {
  return Math.round(value * 1000000)/1000000;
}

function ff(value) {
  return Math.round(value * 1000000)/1000000;
}

function nf(value) {
  return Math.round(value * 1000000000)/1000000000;
}

function af(value) {
  return Math.round(value * 180/Math.PI * 1000000)/1000000;
}

function sf(value) {
  return Math.round(value * 1000000)/1000000;
}

function rpmf(value) {
  return Math.round(value * 1000000)/1000000;
}

function toVector(value) {
  return {x:nf(value.x),y:nf(value.y),z:nf(value.z)};
}

var program = {};
var cutterLocation = [];

function onOpen() {
  if (programName) {
    program.name = programName;
  }
  if (programComment) {
    program.comment = programComment;
  }
  program.unit = (unit == IN) ? "in" : "mm";
  program.cld = cutterLocation;
}

function onComment(comment) {
  if (comment) {
    cutterLocation.push({comment:comment});
  }
}

function onCommand(command) {
  switch (command) {
  case COMMAND_STOP:
    cutterLocation.push({command:'stop'});
    break;
  case COMMAND_OPTIONAL_STOP:
    cutterLocation.push({command:'optional stop'});
    break;
  case COMMAND_SPINDLE_CLOCKWISE:
    cutterLocation.push({spindle:{direction:'cw'}});
    break;
  case COMMAND_SPINDLE_COUNTERCLOCKWISE:
    cutterLocation.push({spindle:{direction:'ccw'}});
    break;
  case COMMAND_START_SPINDLE:
    cutterLocation.push({spindle:{power:'on'}});
    break;
  case COMMAND_STOP_SPINDLE:
    cutterLocation.push({spindle:{power:'off'}});
    break;
  case COMMAND_ORIENTATE_SPINDLE:
    cutterLocation.push({spindle:{orientation:0}});
    break;
  case COMMAND_COOLANT_ON:
    cutterLocation.push({coolant:{active:true}});
    break;
  case COMMAND_COOLANT_OFF:
    cutterLocation.push({coolant:{active:false}});
    break;
  case COMMAND_START_CHIP_TRANSPORT:
    cutterLocation.push({command:'start chip transport'});
    break;
  case COMMAND_STOP_CHIP_TRANSPORT:
    cutterLocation.push({command:'stop chip transport'});
    break;
  case COMMAND_OPEN_DOOR:
    cutterLocation.push({command:'open door'});
    break;
  case COMMAND_CLOSE_DOOR:
    cutterLocation.push({command:'close door'});
    break;
  case COMMAND_CALIBRATE:
    cutterLocation.push({command:'calibrate'});
    break;
  case COMMAND_VERIFY:
    cutterLocation.push({command:'verify'});
    break;
  case COMMAND_CLEAN:
    cutterLocation.push({command:'clean'});
    break;
  case COMMAND_ALARM:
    cutterLocation.push({command:'alarm'});
    break;
  case COMMAND_ALERT:
    cutterLocation.push({command:'alert'});
    break;
  }
}

var currentCoolant;

function setCoolant(coolant) {
  if (currentCoolant == coolant) {
    return;
  }
  cutterLocation.push({coolant:{active:(coolant != COOLANT_OFF)}});
  switch (coolant) {
  case COOLANT_OFF:
    break;
  case COOLANT_FLOOD:
    cutterLocation.push({coolant:{mode:'flood'}});
    break;
  case COOLANT_MIST:
    cutterLocation.push({coolant:{mode:'mist'}});
    break;
  case COOLANT_THROUGH_TOOL:
    cutterLocation.push({coolant:{mode:'through tool'}});
    break;
  case COOLANT_AIR:
    cutterLocation.push({coolant:{mode:'air'}});
    break;
  case COOLANT_AIR_THROUGH_TOOL:
    cutterLocation.push({coolant:{mode:'air through tool'}});
    break;
  case COOLANT_SUCTION:
    cutterLocation.push({coolant:{mode:'suction'}});
    break;
  case COOLANT_FLOOD_MIST:
    cutterLocation.push({coolant:{mode:'flood mist'}});
    break;
  case COOLANT_FLOOD_THROUGH_TOOL:
    cutterLocation.push({coolant:{mode:'flood through tool'}});
    break;
  }
}

function onCoolant(coolant) {
  setCoolant(coolant);
}

function onParameter(name, value) {
  cutterLocation.push({p:{name:name,value:value}});
}

function onSection() {
  currentFeed = undefined;
  
  if (currentSection.isOptional()) {
    cutterLocation.push({optional:true});
  }
  
  if (currentSection.getType() == TYPE_TURNING) {
    cutterLocation.push({type:'turning'});
    cutterLocation.push({tool:{number:tool.number,compensationOffset:tool.compensationOffset}});
  } else if (currentSection.getType() == TYPE_MILLING) {
    cutterLocation.push({type:'milling'});
    cutterLocation.push({tool:{number:tool.number,lengthOffset:tool.lengthOffset,diameterOffset:tool.diameterOffset,diameter:f(tool.diameter),cornerRadius:f(tool.cornerRadius),taperAngle:af(tool.taperAngle),bodyLength:f(tool.bodyLength)}});
  } else if (currentSection.getType() == TYPE_JET) {
    cutterLocation.push({type:'jet'});
    cutterLocation.push({tool:{number:tool.number,lengthOffset:tool.lengthOffset,diameterOffset:tool.diameterOffset,diameter:f(tool.jetDiameter),distance:f(tool.jetDistance)}});
  } else {
    cutterLocation.push({type:''});
    cutterLocation.push({tool:{number:tool.number}});
  }

  cutterLocation.push({workPlane:{right:toVector(currentSection.workPlane.right),up:toVector(currentSection.workPlane.up),forward:toVector(currentSection.workPlane.forward),origin:toVector(currentSection.workOrigin)}});
  cutterLocation.push({workOffset:currentSection.workOffset});
  cutterLocation.push({spindle:{speed:rpmf(tool.spindleRPM),direction:(tool.clockwise ? "cw" : "ccw")}});
  
  setCoolant(tool.coolant);
}

function onDwell(seconds) {
  program.push({dwell:sf(seconds)}); // in seconds
}

function onRadiusCompensation() {
  switch (radiusCompensation) {
  case RADIUS_COMPENSATION_OFF:
    program.push({cutterCompensation:{mode:'center'}});
    break;
  case RADIUS_COMPENSATION_LEFT:
    program.push({cutterCompensation:{mode:'left'}});
    break;
  case RADIUS_COMPENSATION_RIGHT:
    program.push({cutterCompensation:{mode:'right'}});
    break;
  }
}

var currentFeed;

function onFeedrate(feed) {
  if (currentFeed != feed) {
    currentFeed = feed;
    if (feed >= 0) {
      cutterLocation.push({f:ff(feed)});
    } else {  
      cutterLocation.push({f:'rapid'});
    }
  }
}

function onRapid(x, y, z) {
  onFeedrate(-1);
  cutterLocation.push({l:{x:f(x),y:f(y),z:f(z)}});
}

function onLinear(x, y, z, feed) {
  onFeedrate(feed);
  cutterLocation.push({l:{x:f(x),y:f(y),z:f(z)}});
}

function onRapid5D(x, y, z, dx, dy, dz) {
  onFeedrate(-1);
  cutterLocation.push({l:{x:f(x),y:f(y),z:f(z),tx:nf(dx),ty:nf(dy),tz:nf(dz)}});
}

function onLinear5D(x, y, z, dx, dy, dz, feed) {
  onFeedrate(feed);
  cutterLocation.push({l:{x:f(x),y:f(y),z:f(z),tx:nf(dx),ty:nf(dy),tz:nf(dz)}});
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  onFeedrate(feed);
  var n = getCircularNormal();
  if (clockwise) {
    n = Vector.product(n, -1);
  }
  cutterLocation.push(
    {c:{x:f(x),y:f(y),z:f(z),cx:f(cx),cy:f(cy),cz:f(cz),nx:nf(n.x),ny:nf(n.y),nz:nf(n.z),a:af(getCircularSweep())}}
  );
}

var object;

function onCycle() {
  
  object = {};
  object.clearance = f(cycle.clearance);
  object.retract = f(cycle.retract);
  if (cycle.feedrate > 0) {
    object.feedrate = ff(cycle.feedrate);
  }
  if (cycle.retractFeedrate > 0) {
    object.retractFeedrate = ff(cycle.retractFeedrate);
  }
  if (cycle.dwell > 0) {
    object.dwell = sf(cycle.dwell);
  }
  if (cycle.incrementalDepth > 0) {
    object.incrementalDepth = f(cycle.incrementalDepth);
  }
  if (cycle.accumulatedDepth > 0) {
    object.accumulatedDepth = f(cycle.accumulatedDepth);
  }
  object.locations = [];
  
  switch (cycleType) {
  case "drilling":
    object.type = 'drill';
    cutterLocation.push(object);
    break;
  case "counter-boring":
    object.type = 'drill';
    cutterLocation.push(object);
    break;
  case "reaming":
    object.type = 'reaming';
    cutterLocation.push(object);
    break;
  case "boring":
    object.type = 'boring';
    cutterLocation.push(object);
    // statement += ", ORIANT, " + 0; // unknown orientation
    break;
  case "fine-boring":
    object.type = 'fineBoring';
    cutterLocation.push(object);
    //statement = "CYCLE/BORE, " + d + ", " + feedUnit + ", " + f + ", " + c + ", " + cycle.shift;
    //statement += ", ORIANT, " + 0; // unknown orientation
    break;
  case "deep-drilling":
    object.type = 'deepDrilling';
    cutterLocation.push(object);
    break;
  case "chip-breaking":
    object.type = 'chipBreaking';
    cutterLocation.push(object);
    break;
  case "tapping":
    object.type = 'tapping';
    cutterLocation.push(object);
    break;
  case "left-tapping":
    object.type = 'tapping';
    cutterLocation.push(object);
    break;
  case "right-tapping":
    object.type = 'tapping';
    break;
  default:
    cycleExpanded = true;
  }
}

function onCyclePoint(x, y, z) {
  if (cycleExpanded) {
    expandCyclePoint(x, y, z);
    return;
  }
  object.locations.push(
    {l:{x:f(x),y:f(y),z:f(z)}}
  );
}

function onCycleEnd() {
  if (!cycleExpanded) {
    cutterLocation.push(object);
  }
}

function onSectionEnd() {
  if (currentSection.isOptional()) {
    cutterLocation.push({optional:false});
  }
}

function onClose() {
  var p = program;
  if (properties.pretty) {
    writeln(JSON.stringify(p, null, '  '));
  } else {
    writeln(JSON.stringify(p));
  }
}
