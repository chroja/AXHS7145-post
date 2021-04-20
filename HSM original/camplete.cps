/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  CAMPlete APT post processor configuration.

  $Revision: 40091 $
  $Date: 2015-10-14 17:29:32 +0200 (on, 14 okt 2015) $
  
  FORKID {ADF192AD-B49D-44CF-9FB0-75F7AB9D2059}
*/

// ATTENTION: this post requires CAMplete TruePath build 677 or later

description = "CAMplete APT";
vendor = "CAMplete";
vendorUrl = "http://www.camplete.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;

longDescription = "This post interfaces to CAMplete TruePath build 677 or later. The post creates the required project files with the tool information and model and stock for automatic import into CAMplete TruePath.";

unit = ORIGINAL_UNIT; // do not map unit
capabilities = CAPABILITY_INTERMEDIATE;
extension = "apt";
setCodePage("utf-8");

allowHelicalMoves = true;
allowedCircularPlanes = (1 << PLANE_XY) | (1 << PLANE_ZX) | (1 << PLANE_YZ); // only XY, ZX, and YZ planes

// user-defined properties
properties = {
  onlyXYArcs: true // use arc output only on XY plane
};
  
this.exportStock = true;
this.exportPart = true;
this.exportFixture = true;

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});

// collected state
var currentFeed;
var feedUnit;
var coolantActive = false;
var radiusCompensationActive = false;
var destPath = FileSystem.getFolderPath(getOutputPath());

function writeComment(text) {
  writeln("PPRINT/'" + filterText(text, "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789(.,)/-+*= \t") + "'");
}

function onOpen() {
  if (properties.onlyXYArcs) {
    allowedCircularPlanes = 1 << PLANE_XY; // arcs on XY plane only
  }

  var machineId = machineConfiguration.getModel();
  writeln("MACHIN/" + machineId);
  writeln("MODE/" + (isMilling() ? "MILL" : "TURN")); // first statement for an operation
  writeln("PARTNO/'" + programName + "'");
  writeComment(programName);
  writeComment(programComment);
}

function onComment(comment) {
  writeComment(comment);
}

var mapCommand = {
  COMMAND_STOP:"STOP",
  COMMAND_OPTIONAL_STOP:"OPSTOP",
  COMMAND_STOP_SPINDLE:"SPINDL/ON",
  COMMAND_START_SPINDLE:"SPINDL/OFF",

  // COMMAND_ORIENTATE_SPINDLE
  
  COMMAND_SPINDLE_CLOCKWISE:"SPINDL/CLW",
  COMMAND_SPINDLE_COUNTERCLOCKWISE:"SPINDL/CCLW"
  
  // COMMAND_ACTIVATE_SPEED_FEED_SYNCHRONIZATION
  // COMMAND_DEACTIVATE_SPEED_FEED_SYNCHRONIZATION
};

function onCommand(command) {
  switch (command) {
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    writeln("CSI_SET_PATH_PARAM/TOOL_BREAK=ON");  
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  if (mapCommand[command]) {
    writeln(mapCommand[command]);
  } else {
    warning("Unsupported command: " + getCommandStringId(command));
    writeComment("Unsupported command: " + getCommandStringId(command));
  }
}

function onCoolant() {
  if (coolant == COOLANT_OFF) {
    if (coolantActive) {
      writeln("COOLNT/OFF");
      coolantActive = false;
    }
  } else {
    if (!coolantActive) {
      writeln("COOLNT/ON");
      coolantActive = true;
    }

    var mapCoolant = {COOLANT_FLOOD:"flood", COOLANT_MIST:"MIST", COOLANT_TOOL:"THRU"};
    if (mapCoolant[coolant]) {
      writeln("COOLNT/" + mapCoolant[coolant]);
    } else {
      warning("Unsupported coolant mode: " + coolant);
      writeComment("Unsupported coolant mode: " + coolant);
    }
  }
}

function onSection() {
  writeln("");
  writeln("PPRINT/'NEW SECTION'");
  // writeln("PPRINT/'Type: " + currentSection.getType() + "'")
  if (hasParameter("operation-strategy")) {
    var strategy = getParameter("operation-strategy");
    if (strategy) {
      writeln("PPRINT/'Strategy: " + strategy + "'");
    }
  }
  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeln("PPRINT/'Comment: " + comment + "'");
      writeln("CSI_TOOL_PATH/" + comment);
    }
  }
  writeln(""); 
  writeln("UNITS/" + ((unit == IN) ? "INCHES" : "MM"));
  feedUnit = (unit == IN) ? "IPM" : "MMPM";

  if (currentSection.isMultiAxis()) {
    writeln("MULTAX/ON");
  } else {
    writeln("MULTAX/OFF");
  }

  var w = currentSection.workPlane;
  var o = currentSection.workOrigin;
  writeln("");
  writeln("PPRINT/'MATRIX DEFINITION'");
  writeln("PPRINT/'Output x(i),y(i),z(i)'");
  writeln("PPRINT/'Output x(j),y(j),z(j)'");
  writeln("PPRINT/'Output x(k),y(k),z(k)'");
  writeln("PPRINT/'Output dx,dy,dz'");
  writeln("MCS/" + (w.right.x) + ", " + (w.right.y) + ", " + (w.right.z) + ", $");
  writeln((w.up.x) + ", " + (w.up.y) + ", " + (w.up.z) + ", $");
  writeln((w.forward.x) + ", " + (w.forward.y) + ", " + (w.forward.z) + ", $");
  writeln((o.x) + ", " + (o.y) + ", " + (o.z));
  writeln("");
  
  var d = tool.diameter;
  var r = tool.cornerRadius;
  var e = 0;
  var f = 0;
  var a = 0;
  var b = 0;
  var h = tool.bodyLength;
  writeln("CUTTER/" + d + ", " + r + ", " + e + ", " + f + ", " + a + ", " + b + ", " + h);

  var t = tool.number;
  var p = 0;
  var l = tool.bodyLength;
  var o = tool.lengthOffset;
  writeln("LOADTL/" + t + ", " + p + ", " + l + ", " + o);
  // writeln("OFSTNO/" + 0); // not used

  if (tool.breakControl) {
    onCommand(COMMAND_BREAK_CONTROL);
  }
  
  if (isMilling()) {
    writeln("SPINDL/" + "RPM," + tool.spindleRPM + "," + (tool.clockwise ? "CLW" : "CCLW"));
  }
  
  if (isTurning()) {
    writeln(
      "SPINDL/" + tool.spindleRPM + ", " + ((unit == IN) ? "SFM" : "SMM") + ", " + (tool.clockwise ? "CLW" : "CCLW")
    );
  }
  
  // CSI - Coolant Support
  switch (tool.coolant) {
  case COOLANT_OFF:
    // TAG: make sure we disabled coolant between sections
    break;
  case COOLANT_FLOOD:
    writeln("COOLNT/FLOOD");
    break;
  case COOLANT_MIST:
    writeln("COOLNT/MIST");
    break;
  case COOLANT_THROUGH_TOOL:
    writeln("COOLNT/THRU");
    break;
  /*
  case COOLANT_AIR:
    break;
  case COOLANT_AIR_THROUGH_TOOL:
    break;
  case COOLANT_SUCTION:
    break;
  */
  case COOLANT_FLOOD_MIST:
    writeln("COOLNT/FLOOD");
    writeln("COOLNT/MIST");
    break;
  case COOLANT_FLOOD_THROUGH_TOOL:
    writeln("COOLNT/FLOOD");
    writeln("COOLNT/THRU");
    break;
  default:
    warning(localize("Unsupported coolant."));
  }
  // CSI - End Coolant Support
  
  // writeln("ORIGIN/" + currentSection.workOrigin.x + ", " + currentSection.workOrigin.y + ", " + currentSection.workOrigin.z);
}

function onDwell(time) {
  writeln("DELAY/" + time); // in seconds
}

function onRadiusCompensation() {
  if (radiusCompensation == RADIUS_COMPENSATION_OFF) {
    if (radiusCompensationActive) {
      radiusCompensationActive = false;
      writeln("CUTCOM/OFF");
    }
  } else {
    if (!radiusCompensationActive) {
      radiusCompensationActive = true;
      writeln("CUTCOM/ON");
    }
    var direction = (radiusCompensation == RADIUS_COMPENSATION_LEFT) ? "LEFT" : "RIGHT";
    if (tool.diameterOffset != 0) {
      writeln("CUTCOM/" + direction + ", " + tool.diameterOffset);
    } else {
      writeln("CUTCOM/" + direction);
    }
  }
}

function onRapid(x, y, z) {
  writeln("RAPID");
  writeln("GOTO/" + x + ", " + y + ", " + z);
  currentFeed = undefined; // avoid potential problems if user overrides settings within CAMplete
}

function onLinear(x, y, z, feed) {
  if (feed != currentFeed) {
    currentFeed = feed;
    writeln("FEDRAT/" + feed + ", " + feedUnit);
  }
  writeln("GOTO/" + x + ", " + y + ", " + z);
}

function onRapid5D(x, y, z, dx, dy, dz) {
  writeln("RAPID");
  writeln("GOTO/" + x + ", " + y + ", " + z + ", " + dx + ", " + dy + ", " + dz);
  currentFeed = undefined; // avoid potential problems if user overrides settings within CAMplete
}

function onLinear5D(x, y, z, dx, dy, dz, feed) {
  if (feed != currentFeed) {
    currentFeed = feed;
    writeln("FEDRAT/" + feed + ", " + feedUnit);
  }
  writeln("GOTO/" + x + ", " + y + ", " + z + ", " + dx + ", " + dy + ", " + dz);
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (feed != currentFeed) {
    currentFeed = feed;
    writeln("FEDRAT/" + feed + ", " + feedUnit);
  }

  var n = getCircularNormal();
  if (isClockwise()) {
    dir = 1;
  } else {
    dir = -1;
  }
  writeln(
    "CIRCLE/" + cx + ", " + cy + ", " + cz + ", " + (n.x * dir) + ", " + (n.y * dir) + ", " + (n.z * dir) + ", " + getCircularRadius() + ", " + (toDeg(getCircularSweep())) + ", 0.0, 0.0, 0.0"
  );
  writeln("GOTO/" + x + ", " + y + ", " + z);
}

function onSpindleSpeed(spindleSpeed) {
  if (isMilling()) {
    writeln("SPINDL/" + "RPM," + spindleSpeed + "," + (tool.clockwise ? "CLW" : "CCLW"));
  }
  
  if (isTurning()) {
    writeln(
      "SPINDL/" + spindleSpeed + ", " + ((unit == IN) ? "SFM" : "SMM") + ", " + (tool.clockwise ? "CLW" : "CCLW")
    );
  }
}

function onCycle() {
  var d = cycle.depth;
  var f = cycle.feedrate;
  var c = cycle.clearance;
  var r = c - cycle.retract;
  var q = cycle.dwell;
  var i = cycle.incrementalDepth; // for pecking

  var RAPTO = cycle.retract - cycle.stock;
  var RTRCTO = cycle.clearance - cycle.stock;
  
  var statement;
  
  switch (cycleType) {
  case "drilling":
    statement = "CYCLE/DRILL, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c + ", RTRCTO," + RTRCTO;
    if (RAPTO > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    break;
  case "counter-boring":
    statement = "CYCLE/DRILL, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "reaming":
    statement = "CYCLE/REAM, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "boring":
    statement = "CYCLE/BORE, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    statement += ", ORIENT, " + 0; // unknown orientation
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "fine-boring":
    statement = "CYCLE/BORE, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c + ", " + cycle.shift;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    statement += ", ORIENT, " + 0; // unknown orientation
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "deep-drilling":
    statement = "CYCLE/DRILL, DEEP, FEDTO, " + d + ", INCR, " + i + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "chip-breaking":
    statement = "CYCLE/BRKCHP, FEDTO, " + d + ", INCR, " + i + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    if (q > 0) {
      statement += ", DWELL, " + q;
    }
    break;
  case "tapping":
    if (tool.type == TOOL_TAP_LEFT_HAND) {
      cycleNotSupported();
    } else {
      statement = "CYCLE/TAP, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
      if (r > 0) {
        statement += ", RAPTO, " + RAPTO;
      }
    }
    break;
  case "right-tapping":
    statement = "CYCLE/TAP, FEDTO, " + d + ", " + feedUnit + ", " + f + ", CLEAR, " + c;
    if (r > 0) {
      statement += ", RAPTO, " + RAPTO;
    }
    break;
  default:
    cycleNotSupported();
  }
  writeln(statement);
}

function onCyclePoint(x, y, z) {
  writeln("GOTO/" + x + ", " + y + ", " + cycle.stock);
}

function onCycleEnd() {
  writeln("CYCLE/OFF");
  currentFeed = undefined; // avoid potential problems if user overrides settings within CAMplete
}

function onSectionEnd() {
}

function onClose() {
  if (coolantActive) {
    coolantActive = false;
    writeln("COOLNT/OFF");
  }
  writeln("END");
  writeln("FINI");
  createVerificationJob();
  createProjectFile();
  createToolDatabaseFile();
}

function createToolDatabaseFile() {
  // TAG todo:
  // tapered mills

  var xOutput = createVariable({force:true}, xyzFormat);
  var yOutput = createVariable({force:true}, xyzFormat);

  var path = FileSystem.replaceExtension(getOutputPath(), "tdb");
  var file = new TextFile(path, true, "ansi");
  
  file.writeln("<?xml version='1.0' encoding='utf-8' standalone='yes'?>");
  file.writeln("<TOOLDB VER=" + "\"" + "1" + "\"" + ">");
  
  var tools = getToolTable();
  if (tools.getNumberOfTools() > 0) {
    for (var i = 0; i < tools.getNumberOfTools(); ++i) {
      var tool = tools.getTool(i);
      var toolType = tool.getType();
      var holder = tool.holder;
      file.writeln(
        "<TOOL CODE=" + "\"" + tool.number + "\"" + 
        " ID=" + "\"" + getToolTypeName(tool.type) + "\"" + 
        " TYPE=" + "\"" + "MILL" + "\"" + 
        " VER="+ "\"" + "6" + "\"" +
        " TOLERANCE=" + "\"" + "-1" + "\"" +
        " UNITS=" + "\"" + ((unit == IN) ? "IN" : "MM") + "\"" + 
        " OFFSETZ=" + "\"" + "0" + "\"" +
        " DIAMETER=" + "\"" + xyzFormat.format(tool.diameter) + "\"" + " >"
      );
      file.writeln("  <CUTTER TYPE=" + "\"" + "CUSTOM_REVOLUTED" + "\"" + ">");
      file.writeln("    <PROFILE>");
      
      xOutput.format(0); // inital xOutput
      yOutput.format(0); // inital yOutput
      if (tool.cornerRadius > 0) {
        file.writeln("      <ARC DIR=" + "\"" + "CCW" + "\"" + ">");
        file.writeln("        <START>" + xOutput.format((tool.tipDiameter - tool.cornerRadius)/2) + " " + "0</START>");
        file.writeln("        <END>" + xOutput.format((tool.tipDiameter + tool.cornerRadius)/2) + " " + yOutput.format(tool.cornerRadius) + "</END>");
        file.writeln("        <CENTER>" + xOutput.format((tool.tipDiameter - tool.cornerRadius)/2) + " " + yOutput.format(tool.cornerRadius) + "</CENTER>");
        file.writeln("      </ARC>");
      }
      if (tool.taperAngle > 0) {
        file.writeln(
          "      <LINE><START>0 0</START><END>" + 
          xOutput.format(tool.diameter/2) + " " + 
          yOutput.format((tool.diameter/2) / Math.tan(tool.taperAngle/2)) + 
          "</END></LINE>"
        );
      }
      
      file.writeln(
        "      <LINE><START>" + 
        (xOutput.getCurrent()) + " " + 
        (yOutput.getCurrent()) + "</START><END>" + 
        xOutput.format(tool.diameter/2) + " " + 
        yOutput.getCurrent() + "</END></LINE>"
      );
      file.writeln("      <LINE><START>" + xOutput.format(tool.diameter/2) + " " + yOutput.getCurrent() + "</START><END>" + xyzFormat.format(tool.diameter/2) + " " + xyzFormat.format(tool.bodyLength) +"</END></LINE>");
      file.writeln("    </PROFILE>");
      file.writeln("  </CUTTER>");
      //file.writeln("  <SHANK TYPE=" + "\"" + "CUSTOM_REVOLUTED" + "\"" + ">");
      //file.writeln("    <PROFILE>");
      //file.writeln("      <LINE><START>0 15.24</START><END>40.005 15.24</END></LINE>");
      //file.writeln("      <LINE><START>40.005 15.24</START><END>40.005 50.546</END></LINE>");
      //file.writeln("      <LINE><START>40.005 50.546</START><END>0 50.546</END></LINE>");
      //file.writeln("    </PROFILE>");
      //file.writeln("  </SHANK>");
      file.writeln(
      "  <HOLDER TYPE=" + "\"" + "CUSTOM_REVOLUTED" + "\"" + 
      " VER="+ "\"" + "2" + "\"" +
      " POSX="+ "\"" + "0" + "\"" +
      " POSY=" + "\"" + "0" + "\"" +
      " POSZ=" + "\"" + tool.bodyLength + "\"" +
      " RZ=" + "\"" + "0" + "\"" + 
      " RY=" + "\"" + "0" + "\"" + 
      " RX=" + "\"" + "0" + "\"" + ">");
      file.writeln("    <CODE>DEFAULT HOLDER</CODE>");
      file.writeln("      <PROFILE>");
      
      var hCurrent = 0;
      if (holder && holder.hasSections()) {
        var n = holder.getNumberOfSections();
        for (var j = 0; j < n; ++j) {
          if (j == 0) {
            file.writeln("        <LINE><START>0 0</START><END>" + (tool.shaftDiameter/2) + " 0</END></LINE>");
          } else {
            hCurrent = hCurrent + holder.getLength(j - 1); 
            file.writeln(
              "        <LINE><START>" + xyzFormat.format(holder.getDiameter(j - 1)/2) + " " + xyzFormat.format(hCurrent) + "</START>" +
              "<END>" + xyzFormat.format(holder.getDiameter(j)/2) + " " + xyzFormat.format(hCurrent + holder.getLength(j)) + "</END></LINE>"
            );
          }
        }
      }
      file.writeln("      </PROFILE>");
      file.writeln("  </HOLDER>");
      file.writeln("</TOOL>");
    }
  }
  file.writeln("</TOOLDB>");
  file.close();
}

function createProjectFile() {
  var path = FileSystem.replaceExtension(getOutputPath(), "proj");
  var file = new TextFile(path, true, "ansi");

  if (!programName) {
    error(localize("Program name is not specified."));
    return;
  }
  
  file.writeln("<?xml version='1.0' encoding='utf-8' standalone='yes'?>");
  file.writeln("<PROJECTCONFIG>");
  file.writeln(" <SOURCE>");
  file.writeln("  <CAMSYSTEM>Autodesk CAM</CAMSYSTEM>");
  file.writeln("  <VERSION>2014</VERSION>");
  file.writeln("  <PLUGINCREATOR></PLUGINCREATOR>");
  file.writeln("  <PLUGINNAME MAJ_VER=" + "\"" + "1" + "\"" + " MIN_VER=" + "\"" + "1" + "\"" + ">" + description + "</PLUGINNAME>");
  file.writeln(" </SOURCE>");
  file.writeln(" <NAME>" + programName + "</NAME>");
  file.writeln(" <TOOLING>");
  file.writeln("  <TOOLLIBRARY LOADER=" + "\"" + "AUTODESKCAM_CAMPLETE_XML_TOOLING" + "\"" + ">" + ".\\" + programName + ".tdb</TOOLLIBRARY>");
  file.writeln(" </TOOLING>");
  file.writeln(" <TOOLPATHS>");
  file.writeln("  <TOOLPATH LOADER=" + "\"" + "AUTODESKCAM_CAMPLETE_APT" + "\"" + " UNITS=" + "\"" + ((unit == IN) ? "INCHES" : "MM") + "\"" + ">" + ".\\" + programName + "." + extension + "</TOOLPATH>");
  file.writeln(" </TOOLPATHS>");
  file.writeln(" <OFFSETS>");
  // file.writeln("  <OFFSET TYPE="PALLETTOGCODESHIFT" X=\"0\" Y=\"0\" Z=\"3\" UNITS=\"" + ((unit == IN) ? "INCHES" : "MM") + "\"></OFFSET>");
  file.writeln(" </OFFSETS>");
  file.writeln(" <PARTINFO>");
  file.writeln("  <TARGETMODEL LOADER="+ "\"" + "GENERIC_STL" + "\"" + " UNITS=" + "\"" + ((unit == IN) ? "INCHES" : "MM") + "\"" + ">" + ".\\" + programName + "_PART.stl</TARGETMODEL>");
  file.writeln("  <FIXTURE LOADER=" + "\"" + "GENERIC_STL" + "\"" + " UNITS=" + "\"" + ((unit == IN) ? "INCHES" : "MM") + "\"" + ">" + ".\\" + programName + "_FIXTURE.stl</FIXTURE>");
  file.writeln(" </PARTINFO>");
  file.writeln("</PROJECTCONFIG>");
  file.close();
}

var destStockPath = "";
var destPartPath = "";
var destFixturePath = "";

function createVerificationJob() {
  var stockPath;
  if (hasGlobalParameter("autodeskcam:stock-path")) {
    stockPath = getGlobalParameter("autodeskcam:stock-path");
  }
  var partPath;
  if (hasGlobalParameter("autodeskcam:part-path")) {
    partPath = getGlobalParameter("autodeskcam:part-path");
  }
  var fixturePath;
  if (hasGlobalParameter("autodeskcam:fixture-path")) {
    fixturePath = getGlobalParameter("autodeskcam:fixture-path");
  }
  
  
  
  if (!FileSystem.isFolder(destPath)) {
    error(subst(localize("NC verification job folder '%1' does not exist."), destPath));
    return;
  }

  if (!programName) {
    error(localize("Program name is not specified."));
    return;
  }

  if (FileSystem.isFile(stockPath)) {
    destStockPath = FileSystem.getCombinedPath(destPath, programName + "_STOCK.stl");
    FileSystem.copyFile(stockPath, destStockPath);
  }

  if (FileSystem.isFile(partPath)) {
    destPartPath = FileSystem.getCombinedPath(destPath, programName + "_PART.stl");
    FileSystem.copyFile(partPath, destPartPath);
  }

  if (FileSystem.isFile(fixturePath)) {
    destFixturePath = FileSystem.getCombinedPath(destPath, programName + "_FIXTURE.stl");
    FileSystem.copyFile(fixturePath, destFixturePath);
  }
}

function onTerminate() {

  if (!programName) {
    error(localize("Program name is not specified."));
    return;
  }

  var ncFilename = "";
  if (programName) {
    ncFilename += (ncFilename ? "_" : "") + programName;
  }

  if (FileSystem.isFolder(destPath)) {
    var destNCPath = FileSystem.getCombinedPath(destPath, ncFilename + "." + extension);
    if (FileSystem.moveFile) {
      var destNCPathPartial = destNCPath + ".part";
      FileSystem.copyFile(getOutputPath(), destNCPathPartial);
      FileSystem.moveFile(destNCPathPartial, destNCPath);
    } else {
      FileSystem.copyFile(getOutputPath(), destNCPath); // direct
    }
  }
}
