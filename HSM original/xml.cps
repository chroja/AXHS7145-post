/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  $Revision: 40091 $
  $Date: 2015-10-14 17:29:32 +0200 (on, 14 okt 2015) $
  
  FORKID {B9E0E4D8-D548-421b-8F97-CCACF8B1F09F}
*/

description = "XML Cutter Location Data";
vendor = "Autodesk, Inc.";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;

longDescription = "Example post illustrating how to convert the toolpath into XML.";

capabilities = CAPABILITY_INTERMEDIATE;
extension = "xml";
setCodePage("utf-8");

allowHelicalMoves = true;
allowedCircularPlanes = undefined; // allow any circular motion

properties = {
  useTimeStamp: false // enable to output a time stamp
};

var feedOutput = createVariable({});

var mapRCTable = new Table(
  [" compensation='off'", " compensation='left'", "", " compensation='right'"],
  {initial:RADIUS_COMPENSATION_OFF},
  "Invalid radius compensation"
);

function toPos(x, y, z) {
  return x + " " + y + " " + z;
}

function toFeed(feed) {
  var f = feedOutput.format(feed);
  return f ? (" feed='" + f + "'") : "";
}

function toRC(radiusCompensation) {
  return mapRCTable.lookup(radiusCompensation);
/*
  switch (radiusCompensation) {
  case RADIUS_COMPENSATION_OFF:
    return " compensation='off'";
  case RADIUS_COMPENSATION_LEFT:
    return " compensation='left'";
  case RADIUS_COMPENSATION_RIGHT:
    return " compensation='right'";
  }
  return "";
*/
}

function toString(value) {
  if (typeof(value) == 'string') {
    return "\"" + value + "\"";
  } else {
    return value;
  }
}

function onOpen() {
  writeln("<?xml version='1.0' encoding='utf-8' standalone='yes'?>");
  writeln("<nc xmlns='http://www.hsmworks.com/xml/2008/nc' version='1.0'>");
  writeln("<!-- http://cam.autodesk.com -->");
  if (properties.useTimeStamp) {
    var d = new Date();
    writeln("<meta><date timestamp='" + (d.getTime() * 1000) + "'/></meta>");
  }
}

function onComment(text) {
  // TAG: escape
  writeln("<comment>" + text + "</comment>");
}

function onSection() {
  var u = (unit == IN) ? "inches" : "millimeters";
  var o = toPos(currentSection.workOrigin.x, currentSection.workOrigin.y, currentSection.workOrigin.z);
  writeln("<context unit='" + u + "' origin='" + o + "'/>");

  var type = "unspecified"; // TAG: fixme
  var n = tool.number;
  var d = tool.diameter;
  var cr = tool.cornerRadius;
  var ta = tool.taperAngle;
  var fl = tool.fluteLength;
  var sl = tool.shoulderLength;
  var sd = tool.shaftDiameter;
  var bl = tool.bodyLength;
  var tp = tool.threadPitch;
  var _do = tool.diameterOffset;
  var lo = tool.lengthOffset;
  var sr = tool.spindleRPM;
  
  var COOLANT_NAMES = ["disabled", "flood", "mist", "tool", "air", "air through tool"];
  var coolant = COOLANT_NAMES[tool.coolant];
  
  writeln("<tool type='" + type + "' number='" + n + "' diameter='" + d + "' corner-radius='" + cr + "' taper-angle='" + ta + "' flute-length='" + fl + "' shoulder-length='" + sl + "' body-length='" + bl + "' shaft-diameter='" + sd + "' thread-pitch='" + tp + "' diameter-offset='" + _do + "' length-offset='" + lo + "' spindle-rpm='" + sr + "' coolant='" + coolant + "'>");
  var holder = tool.holder;
  if (holder) {
    writeln("<holder>");
    for (var i = 0; i < holder.getNumberOfSections(); ++i) {
      var d = holder.getDiameter(i);
      var l = holder.getLength(i);
      writeln("<section diameter='" + d + "' length='" + l + "'/>");
    }
    writeln("</holder>");
  }
  writeln("</tool>");

  writeln("<section>");

  feedOutput.reset();
}

function onParameter(name, value) {
  // TAG: escape
  var type = "float";
  if (typeof(value) == 'string') {
    type = "string";
  } else if ((value % 1) == 0) {
    type = "integer";
  }
  writeln("<parameter name='" + name + "' value='" + toString(value) + "' type='" + type + "'/>");
}

function onDwell(seconds) {
  writeln("<dwell seconds='" + secFormat.format(seconds) + "'/>");
}

function onCycle() {
  writeln("<group id='" + cycleType + "'");
  for (var name in cycle) {
    writeln("<parameter name='" + name + "' value='" + toString(cycle[name]) + "'/>");
  }
}

function onCyclePoint(x, y, z) {
  writeln("<linear to='" + toPos(x, y, z) + "'/>");
}

function onCycleEnd() {
  writeln("</group>");
}

function onRapid(x, y, z) {
  writeln("<rapid to='" + toPos(x, y, z) + "'" + toRC(radiusCompensation) + "/>");
  feedOutput.reset();
}

function onLinear(x, y, z, feed) {
  writeln("<linear to='" + toPos(x, y, z) + "'" + toFeed(feed) + toRC(radiusCompensation) + "/>");
}

function onRapid5D(x, y, z, dx, dy, dz) {
  writeln("<rapid5d to='" + toPos(x, y, z) + "' axis='" + toPos(dx, dy, dz) + "'/>");
  previousFeed = undefined;
}

function onLinear5D(x, y, z, dx, dy, dz, feed) {
  writeln("<linear5d to='" + toPos(x, y, z) + "' axis='" + toPos(dx, dy, dz) + "'" + toFeed(feed) + "/>");
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  var n = getCircularNormal();
  var block = "";
  var big = getCircularSweep() > Math.PI;
  if (big) {
    block += "circular";
  } else {
    block += isClockwise() ? "arc-cw" : "arc-ccw";
  }
  block += " to='" + toPos(x, y, z) + "'";
  block += " center='" + toPos(cx, cy, cz) + "'";
  if ((n.x != 0) || (n.y != 0) || (n.z != 1)) {
    block += " normal='" + toPos(n.x, n.y, n.z) + "'";
  }
  if (big) {
    block += " sweep='" + getCircularSweep() + "'";
  }
  block += toFeed(feed);
  block += toRC(radiusCompensation);
  writeln("<" + block + "/>");
}

function onCommand() {
  writeln("<command/>");
}

function onSectionEnd() {
  writeln("</section>");
}

function onClose() {
  writeln("</nc>");
}
