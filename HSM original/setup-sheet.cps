/**
  Copyright (C) 2012-2015 by Autodesk, Inc.
  All rights reserved.

  Setup sheet configuration.

  $Revision: 40261 $
  $Date: 2015-11-11 15:01:15 +0100 (on, 11 nov 2015) $
  
  FORKID {BC98C807-412C-4ffc-BD2B-ABB3F0A59DB8}
*/

description = "Setup Sheet";
vendor = "Autodesk, Inc.";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2012-2015 by Autodesk, Inc.";
certificationLevel = 2;

longDescription = "Setup sheet for generating an HTML document with the relevant details for the setup, tools, and individual operations. You can print the document directly or alternatively convert it to a PDF file for later reference.";

capabilities = CAPABILITY_SETUP_SHEET;
extension = "html";
mimetype = "text/html";
keywords = "MODEL_IMAGE PREVIEW_IMAGE";
setCodePage("utf-8");
dependencies = "setup-sheet.css";

allowMachineChangeOnSection = true;

properties = {
  embedStylesheet: true, // embeds the stylesheet
  useUnitSymbol: false, // specifies that symbols should be used for units (some printers may not support this)
  showDocumentPath: true, // specifies that the path of the source document should be shown
  showModelImage: true, // specifies that the model image should be shown
  showToolImage: true, // specifies that the tool image should be shown
  showPreviewImage: true, // specifies that the preview image should be shown
  previewWidth: "8cm", // the width of the preview picture
  showPercentages: true, // specifies that the percentage of the total cycle time should be shown for each operation cycle time
  showFooter: true, // specifies that the footer should be shown
  showRapidDistance: true,
  rapidFeed: 5000, // the rapid traversal feed
  toolChangeTime: 15, // the time in seconds for a tool change
  showNotes: true, // show notes for the operations
  forcePreview: false, // enable to force preview picture for all pattern instances
  showOperations: true, // enable to see information for each operation
  showTools: false, // enable to see information for each tools
  showTotals: true // enable to see total information
};

var useToolNumber = true;

var feedFormat = createFormat({decimals:(unit == MM ? 1 : 3)});
var toolFormat = createFormat({decimals:0});
var rpmFormat = createFormat({decimals:0});
var secFormat = createFormat({decimals:3});
var angleFormat = createFormat({decimals:0, scale:DEG});
var pitchFormat = createFormat({decimals:3});
var spatialFormat = createFormat({decimals:(unit == MM ? 2 : 3)});
var percentageFormat = createFormat({decimals:1, scale:100});
var timeFormat = createFormat({decimals:2});
var taperFormat = angleFormat; // share format

// collected state
var zRanges = {};
var totalCycleTime = 0;
var exportedTools = {};
var toolRenderer;

function getUnitSymbolAsString() {
  switch (unit) {
  case MM:
    return properties.useUnitSymbol ? "&#x339c;" : "mm";
  case IN:
    return properties.useUnitSymbol ? "&#x2233;" : "in";
  default:
    error(localize("Unit is not supported."));
    return undefined;
  }
}

function getFeedSymbolAsString() {
  switch (unit) {
  case MM:
    return properties.useUnitSymbol ? "&#x339c;/min" : "mm/min";
  case IN:
    return properties.useUnitSymbol  ? "&#x2233;/min" : "in/min";
    // return properties.useUnitSymbol  ? "&#x2032;/min" : "ft/min";
  default:
    error(localize("Unit is not supported."));
    return undefined;
  }
}

function getFPRSymbolAsString() {
  switch (unit) {
  case MM:
    return properties.useUnitSymbol ? "&#x339c;" : "mm";
  case IN:
    return properties.useUnitSymbol  ? "&#x2233;" : "in";
  default:
    error(localize("Unit is not supported."));
    return undefined;
  }
}

function toString(value) {
  if (typeof(value) == 'string') {
    return "'" + value + "'";
  } else {
    return value;
  }
}

function makeRow(content, classId) {
  if (classId) {
    return "<tr class=\"" + classId + "\">" + content + "</tr>";
  } else {
    return "<tr>" + content + "</tr>";
  }
}

function makeHeading(content, classId) {
  if (classId) {
    return "<th class=\"" + classId + "\">" + content + "</th>";
  } else {
    return "<th>" + content + "</th>";
  }
}

function makeColumn(content, classId) {
  if (classId) {
    return "<td class=\"" + classId + "\">" + content + "</td>";
  } else {
    return "<td>" + content + "</td>";
  }
}

function bold(content, classId) {
  if (classId) {
    return "<b class=\"" + classId + "\">" + content + "</b>";
  } else {
    return "<b>" + content + "</b>";
  }
}

function d(content) {
  return "<div class=\"description\" style=\"display: inline;\">" + content + "</div>";
}

function v(content) {
  return "<div class=\"value\" style=\"display: inline;\">" + content + "</div>";
}

function p(content, classId) {
  if (classId) {
    return "<p class=\"value\">" + content + "</p>";
  } else {
    return "<p>" + content + "</p>";
  }
}

var cachedParameters = {};
var patternIds = {};
var seenPatternIds = {};

function formatPatternId(id) {
  var chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
  var result = "";
  while (id >= 0) {
    result = result + chars.charAt(id % chars.length);
    id -= chars.length;
  }
  return result;
}

function onParameter(name, value) {
  cachedParameters[name] = value;
}

function onOpen() {
  cachedParameters = {};
  
  toolRenderer = createToolRenderer();
  if (toolRenderer) {
    toolRenderer.setBackgroundColor(new Color(1, 1, 1));
    toolRenderer.setFluteColor(new Color(40.0/255, 40.0/255, 40.0/255));
    toolRenderer.setShoulderColor(new Color(80.0/255, 80.0/255, 80.0/255));
    toolRenderer.setShaftColor(new Color(80.0/255, 80.0/255, 80.0/255));
    toolRenderer.setHolderColor(new Color(40.0/255, 40.0/255, 40.0/255));
  }

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

  write(
    "<!DOCTYPE HTML PUBLIC \"-//W3C//DTD HTML 4.01 Transitional//EN\"\n" +
    "                      \"http://www.w3.org/TR/1999/REC-html401-19991224/loose.dtd\">\n"
  );
  write("<html>");
  // header
  var c = "<head>";
  c += "<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\">";
  if (properties.embedStylesheet) {
    c += "<style type=\"text/css\">" + loadText("setup-sheet.css", "utf-8") + "</style>";
  } else {
    c += "<link rel=\"StyleSheet\" href=\"setup-sheet.css\" type=\"text/css\" media=\"print, screen\">";
  }
  c += "<style type=\"text/css\">" + ".preview img {width: " + properties.previewWidth + ";}" + "</style>";
  if (programName) {
    c += "<title>" + localize("Setup Sheet for Program") + " " + programName + "</title>";
  } else {
    c += "<title>" + localize("Setup Sheet") + "</title>";
  }
  c += "</head>";
  write(c);

  write("<body>");
  if (programName) {
    write("<h1>" + localize("Setup Sheet for Program") + " " + programName + "</h1>");
  } else {
    write("<h1>" + localize("Setup Sheet") + "</h1>");
  }

  patternIds = {};
  var numberOfSections = getNumberOfSections();
  var j = 0;
  for (var i = 0; i < numberOfSections; ++i) {
    var section = getSection(i);
    if (section.isPatterned()) {
      var id = section.getPatternId();
      if (patternIds[id] == undefined) {
        patternIds[id] = formatPatternId(j);
        ++j;
      }
    }
  }
}

/**
  Returns the specified coolant as a string.
*/
function getCoolantDescription(coolant) {
  switch (coolant) {
  case COOLANT_OFF:
    return localize("Off");
  case COOLANT_FLOOD:
    return localize("Flood");
  case COOLANT_MIST:
    return localize("Mist");
  case COOLANT_THROUGH_TOOL:
    return localize("Through tool");
  case COOLANT_AIR:
    return localize("Air");
  case COOLANT_AIR_THROUGH_TOOL:
    return localize("Air through tool");
  case COOLANT_SUCTION:
    return localize("Suction");
  case COOLANT_FLOOD_MIST:
    return localize("Flood and mist");
  default:
    return localize("Unknown");
  }
}

/** Formats WCS to text. */
function formatWCS(id) {
  /*
  if (id == 0) {
    id = 1;
  }
  if (id > 6) {
    return "G54.1P" + (id - 6);
  }
  return "G" + (getAsInt(id) + 53);
  */
  return "#" + id;
}

function onSection() {
  skipRemainingSection();
}

function pageWidthFitPath(path) {
  var PAGE_WIDTH = 70;
  if (path.length<PAGE_WIDTH) {
    return path;
  }
  var newPath = "";
  var tempPath = "";
  var flushPath = "";
  var offset = 0;
  var ids = "";
  for (var i = 0; i < path.length; i++) {
    var cv = path[i];
    if (i > PAGE_WIDTH + offset) {
      if (flushPath.length == 0) { // No good place to break
        flushPath = tempPath;
        tempPath = "";
      }
      newPath += flushPath + "<br/>";
      offset += flushPath.length - 1;
      flushPath = "";
    }
    if (cv == "\\" || cv == "/" || cv == " " || cv=="_") {
      flushPath += tempPath + cv;
      tempPath = "";
    } else {
      tempPath += cv;
    }
  }
  newPath += flushPath + tempPath;
  return newPath;
}

function writeTools() {
  writeln("<table class=\"sheet\" cellspacing=\"0\" align=\"center\">");
  var colgroup = "<colgroup span=\"3\"><col width=\"1*\"/><col width=\"1*\"/><col width=\"120\"/></colgroup>";
  write(colgroup);
  write(makeRow("<th colspan=\"3\">" + localize("Tools") + "</th>"));

  var tools = getToolTable();
  if (tools.getNumberOfTools() > 0) {
    var numberOfTools = useToolNumber ? tools.getNumberOfTools() : getNumberOfSections();
    for (var i = 0; i < numberOfTools; ++i) {
      var tool = useToolNumber ? tools.getTool(i) : getSection(i).getTool();

      var c1 = "<table class=\"info\">";
      c1 += makeRow(
        makeColumn(
          bold(localize("T") + toolFormat.format(tool.number)) + " " +
          localize("D") + toolFormat.format(tool.diameterOffset) + " " +
          localize("L") + toolFormat.format(tool.lengthOffset)
        )
      );
      c1 += makeRow(makeColumn(d(localize("Type") + ": ") + v(getToolTypeName(tool.type))));
      c1 += makeRow(makeColumn(d(localize("Diameter") + ": ") + v(spatialFormat.format(tool.diameter) + getUnitSymbolAsString())));
      if (tool.cornerRadius) {
        c1 += makeRow(makeColumn(d(localize("Corner Radius") + ": ") + v(spatialFormat.format(tool.cornerRadius) + getUnitSymbolAsString())));
      }
      if ((tool.taperAngle > 0) && (tool.taperAngle < Math.PI)) {
        if (tool.isDrill()) {
          c1 += makeRow(makeColumn(d(localize("Tip Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
        } else {
          c1 += makeRow(makeColumn(d(localize("Taper Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
        }
      }
      c1 += makeRow(makeColumn(d(localize("Length") + ": ") + v(spatialFormat.format(tool.bodyLength) + getUnitSymbolAsString())));
      c1 += makeRow(makeColumn(d(localize("Flutes") + ": ") + v(tool.numberOfFlutes)));
      if (tool.material) {
        c1 += makeRow(makeColumn(d(localize("Material") + ": ") + v(getMaterialName(tool.material))));
      }
      if (tool.comment) {
        c1 += makeRow(makeColumn(d(localize("Description") + ": ") + v(tool.comment)));
      }
      if (tool.vendor) {
        c1 += makeRow(makeColumn(d(localize("Vendor") + ": ") + v(tool.vendor)));
      }
      //c1 += "<tr class=\"thin\"><td width=\"6cm\">&nbsp;</td></tr>"; // fixed width
      c1 += "</table>";

      var c2 = "<table class=\"tool\">";
      c2 += makeRow(makeColumn("&nbsp;")); // move 1 row down
      if (zRanges[tool.number]) {
        c2 += makeRow(makeColumn(d(localize("Minimum Z") + ": ") + v(spatialFormat.format(zRanges[tool.number].getMinimum()) + getUnitSymbolAsString())));
      }

      var maximumFeed = 0;
      var maximumSpindleSpeed = 0;
      var cuttingDistance = 0;
      var rapidDistance = 0;
      var cycleTime = 0;
      for (var j = 0; j < getNumberOfSections(); ++j) {
        var section = getSection(j);
        if (section.getTool().number == tool.number) {
          maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
          maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
          cuttingDistance += section.getCuttingDistance();
          rapidDistance += section.getRapidDistance();
          cycleTime += section.getCycleTime();
        }
      }
      if (properties.rapidFeed > 0) {
        cycleTime += rapidDistance/properties.rapidFeed * 60;
      }

      c2 += makeRow(makeColumn(d(localize("Maximum Feed") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
      c2 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(rpmFormat.format(maximumSpindleSpeed) + localize("rpm"))));
      c2 += makeRow(makeColumn(d(localize("Cutting Distance") + ": ") + v(spatialFormat.format(cuttingDistance) + getUnitSymbolAsString())));
      if (properties.showRapidDistance) {
        c2 += makeRow(makeColumn(d(localize("Rapid Distance") + ": ") + v(spatialFormat.format(rapidDistance) + getUnitSymbolAsString())));
      }
      var additional = "";
      if ((getNumberOfSections() > 1) && properties.showPercentages) {
        if (totalCycleTime > 0) {
          additional = "<div class=\"percentage\">(" + percentageFormat.format(cycleTime/totalCycleTime) + "%)</div>";
        }
      }
      c2 += makeRow(makeColumn(d(localize("Estimated Cycle Time") + ": ") + v(formatCycleTime(cycleTime) + " " + additional)));
      //c2 += "<tr class=\"thin\"><td width=\"6cm\">&nbsp;</td></tr>"; // fixed width
      c2 += "</table>";

      var c3 = "";
      if (toolRenderer && properties.showToolImage) {
        var id = useToolNumber ? tool.number : (i + 1);
        var path = "tool" + id + ".png";
        var width = 2.5 * 100;
        var height = 2.5 * 133;
        try {
          if (!exportedTools[id]) {
            toolRenderer.exportAs(path, "image/png", tool, width, height);
            exportedTools[id] = true; // do not export twice
          }
          c3 = "<table class=\"info\" cellspacing=\"0\">" +
            makeRow("<td class=\"image\"><img width=\"100px\" src=\"" + path + "\"/></td>") +
            "</table>";
        } catch(e) {
        }
      }
      writeln("");
      
      write(
        makeRow(
          "<td valign=\"top\">" + c1 + "</td>" +
          "<td valign=\"top\">" + c2 + "</td>" +
          "<td class=\"image\" align=\"right\">" + c3 + "</td>",
          "info"
        )
      );
      if ((i + 1) < tools.getNumberOfTools()) {
        write("<tr class=\"space\"><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>");
      }
      writeln("");
      writeln("");
    }
  }

  writeln("</table>");
  writeln("");
}

function onSectionEnd() {
  if (isFirstSection()) {
    var c = "";
    
    if (programComment) {
      c += makeRow(makeColumn(d(localize("Program Comment") + ": ") + v(programComment)));
    }

    if (hasParameter("job-description")) {
      var description = getParameter("job-description");
      if (description) {
        c += makeRow(makeColumn(d(localize("Job Description") + ": ") + v(description)));
      }
    }

    if (hasParameter("iso9000/document-control")) {
      var id = getParameter("iso9000/document-control");
      if (id) {
        c += makeRow(makeColumn(d(localize("Job ISO-9000 Control") + ": ") + v(id)));
      }
    }

    if (properties.showDocumentPath) {
      if (hasParameter("document-path")) {
        var path = getParameter("document-path");
        if (path) {
          c += makeRow(makeColumn(d(localize("Document Path") + ": ") + v(pageWidthFitPath(path))));
        }
      }

      if (hasParameter("document-version")) {
        var version = getParameter("document-version");
        if (version) {
          c += makeRow(makeColumn(d(localize("Document Version") + ": ") + v(version)));
        }
      }
    }

    if (properties.showNotes && hasParameter("job-notes")) {
      var notes = getParameter("job-notes");
      if (notes) {
        c +=
          "<tr class=\"notes\"><td valign=\"top\">" +
          d(localize("Notes")) + ": <pre>" + getParameter("job-notes") +
          "</pre></td></tr>";
      }
    }

    if (c) {
      write("<table class=\"jobhead\" align=\"center\">" + c + "</table>");
      write("<br>");
      writeln("");
      writeln("");
    }

    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero() || modelImagePath && properties.showModelImage) {

      write("<table class=\"job\" cellspacing=\"0\" align=\"center\">");
      write(makeRow("<th colspan=\"2\">" + localize("Job") + "</th>"));
      write("<tr>");

      var numberOfColumns = 0;
      { // stock - workpiece
        if (delta.isNonZero()) {
          var c = "<table class=\"info\" cellspacing=\"0\">";

          var workOffset = undefined;
          var multipleWCS = false;
          var numberOfSections = getNumberOfSections();
          var workOffsets = [];
          for (var i = 0; i < numberOfSections; ++i) {
            var section = getSection(i);
            if (!workOffsets[section.workOffset]) {
              workOffsets[section.workOffset] = true;
            }
            if (!workOffset) {
              workOffset = section.workOffset;
            }
            if (workOffset != section.workOffset) {
              multipleWCS = true;
            }
          }
          var text = "";
          for (var id in workOffsets) {
            text += " " + formatWCS(id);
          }
          c += makeRow(makeColumn(d(localize("WCS")) + ":" + text));
 
          if (multipleWCS) {
            c += makeRow(makeColumn(d(localize("Program uses multiple WCS!"))));
          }

          c += makeRow(makeColumn(
            d(localize("Stock")) + ": <br>&nbsp;&nbsp;" + v(localize("DX") + ": " + spatialFormat.format(delta.x) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v(localize("DY") + ": " + spatialFormat.format(delta.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v(localize("DZ") + ": " + spatialFormat.format(delta.z) + getUnitSymbolAsString())
          ));

          if (hasParameter("part-lower-x") && hasParameter("part-lower-y") && hasParameter("part-lower-z") &&
              hasParameter("part-upper-x") && hasParameter("part-upper-y") && hasParameter("part-upper-z")) {
            var lower = new Vector(getParameter("part-lower-x"), getParameter("part-lower-y"), getParameter("part-lower-z"));
            var upper = new Vector(getParameter("part-upper-x"), getParameter("part-upper-y"), getParameter("part-upper-z"));
            var delta = Vector.diff(upper, lower);
            c += makeRow(makeColumn(
              d(localize("Part")) + ": <br>&nbsp;&nbsp;" + v(localize("DX") + ": " + spatialFormat.format(delta.x) + getUnitSymbolAsString() + "<br>&nbsp;&nbsp;" + v(localize("DY") + ": " + spatialFormat.format(delta.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v(localize("DZ") + ": " + spatialFormat.format(delta.z) + getUnitSymbolAsString()))
            ));
          }

          c += makeRow(makeColumn(
            d(localize("Stock Lower in WCS") + " " + formatWCS(workOffset)) + ": <br>&nbsp;&nbsp;" + v("X: " + spatialFormat.format(workpiece.lower.x) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Y: " + spatialFormat.format(workpiece.lower.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Z: " + spatialFormat.format(workpiece.lower.z) + getUnitSymbolAsString())
          ));
          c += makeRow(makeColumn(
            d(localize("Stock Upper in WCS") + " " + formatWCS(workOffset)) + ": <br>&nbsp;&nbsp;" + v("X: " + spatialFormat.format(workpiece.upper.x) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Y: " + spatialFormat.format(workpiece.upper.y) + getUnitSymbolAsString()) + "<br>&nbsp;&nbsp;" + v("Z: " + spatialFormat.format(workpiece.upper.z) + getUnitSymbolAsString())
          ));

          c += "</table>";
          write(makeColumn(c));
          ++numberOfColumns;
        }
      }

      if (modelImagePath && properties.showModelImage) {
        var path = FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), modelImagePath);
        if (!FileSystem.isFile(path)) {
          warning(subst(localize("Model image doesn't exist '%1'."), path));
        }
        
        ++numberOfColumns;
        var alignment = (numberOfColumns <= 1) ? "center" : "right";
        write("<td class=\"model\" align=\"" + alignment + "\"><img src=\"" + modelImagePath + "\"/></td>");
      }

      write("</tr>");
      write("</table>");
      write("<br>");
      writeln("");
      writeln("");
    }

    if (properties.showTotals) {
      writeTotals();
      write("<br>");
      writeln("");
      writeln("");
    }

    if (properties.showTools) {
      writeTools();
      write("<br>");
      writeln("");
      writeln("");
    }
  }

  if (!properties.showOperations) {
    return; // skip
  }

  if (isFirstSection()) {
    writeln("<table class=\"sheet\" cellspacing=\"0\" align=\"center\">");
  }
  
  var c1 = "<table class=\"info\" cellspacing=\"0\">";

  c1 += makeRow(
    makeColumn(v(localize("Operation") + " " + (currentSection.getId() + 1) + "/" + getNumberOfSections()))
  );

  if (hasParameter("operation-comment")) {
    c1 += makeRow(
      makeColumn(d(localize("Description") + ": ") + v(getParameter("operation-comment")))
    );
  }

  if (hasParameter("operation-strategy")) {
    var strategies = {
      drill: localize("Drilling"),
      face: localize("Facing"),
      path3d: localize("3D Path"),
      pocket2d: localize("Pocket 2D"),
      contour2d: localize("Contour 2D"),
      adaptive2d: localize("Adaptive 2D"),
      slot: localize("Slot"),
      circular: localize("Circular"),
      bore: localize("Bore"),
      thread: localize("Thread"),
      
      contour_new: localize("Contour"),
      contour: localize("Contour"),
      parallel_new: localize("Parallel"),
      parallel: localize("Parallel"),
      pocket_new: localize("Pocket"),
      pocket: localize("Pocket"),
      adaptive: localize("Adaptive"),
      horizontal_new: localize("Horizontal"),
      horizontal: localize("Horizontal"),
      flow: localize("Flow"),
      morph: localize("Morph"),
      pencil_new: localize("Pencil"),
      pencil: localize("Pencil"),
      project: localize("Project"),
      ramp: localize("Ramp"),
      radial_new: localize("Radial"),
      radial: localize("Radial"),
      scallop_new: localize("Scallop"),
      scallop: localize("Scallop"),
      morphed_spiral: localize("Morphed Spiral"),
      spiral_new: localize("Spiral"),
      spiral: localize("Spiral"),
      swarf5d: localize("Multi-Axis Swarf"),
      multiAxisContour: localize("Multi-Axis Contour")
    };
    var description = "";
    if (strategies[getParameter("operation-strategy")]) {
      description = strategies[getParameter("operation-strategy")];
    } else {
      description = localize("Unspecified");
    }
    c1 += makeRow(
      makeColumn(d(localize("Strategy") + ": ") + v(description))
    );
  }

  var newWCS = !isFirstSection() && (currentSection.workOffset != getPreviousSection().workOffset);
  c1 += makeRow(
    makeColumn(d(localize("WCS") + ": ") + v(formatWCS(currentSection.workOffset) + (newWCS ? (" " + bold(localize("NEW!"))) : "")))
  );
  if (currentSection.isPatterned()) {
    var id = patternIds[currentSection.getPatternId()];
    c1 += makeRow(
      makeColumn(d(localize("Pattern Group") + ": ") + v(id))
    );
  }

  var tolerance = cachedParameters["operation:tolerance"];
  var stockToLeave = cachedParameters["operation:stockToLeave"];
  var axialStockToLeave = cachedParameters["operation:verticalStockToLeave"];
  var maximumStepdown = cachedParameters["operation:maximumStepdown"];
  var maximumStepover = cachedParameters["operation:maximumStepover"] ? cachedParameters["operation:maximumStepover"] : cachedParameters["operation:stepover"];
  var optimalLoad = cachedParameters["operation:optimalLoad"];
  var loadDeviation = cachedParameters["operation:loadDeviation"];

  if (tolerance != undefined) {
    c1 += makeRow(makeColumn(d(localize("Tolerance") + ": ") + v(spatialFormat.format(tolerance) + getUnitSymbolAsString())));
  }
  if (stockToLeave != undefined) {
    if ((axialStockToLeave != undefined) && (stockToLeave != axialStockToLeave)) {
      c1 += makeRow(
        makeColumn(
          d(localize("Stock to Leave") + ": ") + v(spatialFormat.format(stockToLeave) + getUnitSymbolAsString()) + "/" + v(spatialFormat.format(axialStockToLeave) + getUnitSymbolAsString())
        )
      );
    } else {
      c1 += makeRow(makeColumn(d(localize("Stock to Leave") + ": ") + v(spatialFormat.format(stockToLeave) + getUnitSymbolAsString())));
    }
  }

  if ((maximumStepdown != undefined) && (maximumStepdown > 0)) {
    c1 += makeRow(makeColumn(d(localize("Maximum stepdown") + ": ") + v(spatialFormat.format(maximumStepdown) + getUnitSymbolAsString())));
  }

  if ((optimalLoad != undefined) && (optimalLoad > 0)) {
    c1 += makeRow(makeColumn(d(localize("Optimal load") + ": ") + v(spatialFormat.format(optimalLoad) + getUnitSymbolAsString())));
    if ((loadDeviation != undefined) && (loadDeviation > 0)) {
      c1 += makeRow(makeColumn(d(localize("Load deviation") + ": ") + v(spatialFormat.format(loadDeviation) + getUnitSymbolAsString())));
    }
  } else if ((maximumStepover != undefined) && (maximumStepover > 0)) {
    c1 += makeRow(makeColumn(d(localize("Maximum stepover") + ": ") + v(spatialFormat.format(maximumStepover) + getUnitSymbolAsString())));
  }

  var compensationType = hasParameter("operation:compensationType") ? getParameter("operation:compensationType") : "computer";
  if (compensationType != "computer") {
    var compensationDeltaRadius = hasParameter("operation:compensationDeltaRadius") ? getParameter("operation:compensationDeltaRadius") : 0;

    var compensation = hasParameter("operation:compensation") ? getParameter("operation:compensation") : "center";
    var COMPENSATIONS = {left: localize("left"), right: localize("right"), center: localize("center")};
    var compensationText = localize("unspecified");
    if (COMPENSATIONS[compensation]) {
      compensationText = COMPENSATIONS[compensation];
    }

    var DESCRIPTIONS = {computer: localize("computer"), control: localize("control"), wear: localize("wear"), inverseWear: localize("inverse wear")};
    var description = localize("unspecified");
    if (DESCRIPTIONS[compensationType]) {
      description = DESCRIPTIONS[compensationType];
    }
    c1 += makeRow(makeColumn(d(localize("Compensation") + ": ") + v(description + " (" + compensationText + ")")));
    c1 += makeRow(makeColumn(d(localize("Safe Tool Diameter") + ": ") + v("< " + spatialFormat.format(tool.diameter + 2 * compensationDeltaRadius) + getUnitSymbolAsString())));
  }
  c1 += "</table>";

  var c2 = "<table class=\"info\" cellspacing=\"0\">";
  c2 += makeRow(makeColumn(v("&nbsp;"))); // move 1 row down

  if (is3D()) {
    var zRange = currentSection.getGlobalZRange();
    c2 += makeRow(makeColumn(d(localize("Maximum Z") + ": ") + v(spatialFormat.format(zRange.getMaximum()) + getUnitSymbolAsString())));
    c2 += makeRow(makeColumn(d(localize("Minimum Z") + ": ") + v(spatialFormat.format(zRange.getMinimum()) + getUnitSymbolAsString())));
  }

  var maximumFeed = currentSection.getMaximumFeedrate();
  var maximumSpindleSpeed = currentSection.getMaximumSpindleSpeed();
  var cuttingDistance = currentSection.getCuttingDistance();
  var rapidDistance = currentSection.getRapidDistance();
  var cycleTime = currentSection.getCycleTime();

  if (currentSection.getType() == TYPE_TURNING) {
    if (currentSection.getTool().getSpindleMode() == SPINDLE_CONSTANT_SURFACE_SPEED) {
      c2 += makeRow(makeColumn(d(localize("Surface Speed") + ": ") + v(rpmFormat.format(currentSection.getTool().surfaceSpeed * ((unit == MM) ? 1/1000.0 : 1/12.0)) + ((unit == MM) ? localize("m/min") : localize("ft/min")))));
    } else {
      c2 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(rpmFormat.format(maximumSpindleSpeed) + localize("rpm"))));
    }
    if (currentSection.feedMode == FEED_PER_REVOLUTION) {
      if (hasParameter("operation:tool_feedCuttingRel")) {
        var feed = getParameter("operation:tool_feedCuttingRel");
        c2 += makeRow(makeColumn(d(localize("Feedrate per Rev") + ": ") + v(feedFormat.format(feed) + getFPRSymbolAsString())));
      }
    } else {
      c2 += makeRow(makeColumn(d(localize("Maximum Feedrate") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
    }
  } else {
    c2 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(rpmFormat.format(maximumSpindleSpeed) + localize("rpm"))));
    c2 += makeRow(makeColumn(d(localize("Maximum Feedrate") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
  }
  c2 += makeRow(makeColumn(d(localize("Cutting Distance") + ": ") + v(spatialFormat.format(cuttingDistance) + getUnitSymbolAsString())));
  if (properties.showRapidDistance) {
    c2 += makeRow(makeColumn(d(localize("Rapid Distance") + ": ") + v(spatialFormat.format(rapidDistance) + getUnitSymbolAsString())));
  }
  if (properties.rapidFeed > 0) {
    cycleTime += rapidDistance/properties.rapidFeed * 60;
  }
  var additional = "";
  if ((getNumberOfSections() > 1) && properties.showPercentages) {
    if (totalCycleTime > 0) {
      additional = "<div class=\"percentage\">(" + percentageFormat.format(cycleTime/totalCycleTime) + "%)</div>";
    }
  }
  c2 += makeRow(makeColumn(d(localize("Estimated Cycle Time") + ": ") + v(formatCycleTime(cycleTime) + " " + additional)));
  c2 += makeRow(makeColumn(d(localize("Coolant") + ": ") + v(getCoolantDescription(tool.coolant))));

  c2 += "</table>";

  var c3 = "<table class=\"info\" cellspacing=\"0\">";
  c3 += makeRow(makeColumn("&nbsp;"));
  c3 += makeRow(
    makeColumn(
      bold(localize("T") + toolFormat.format(tool.number)) + " " +
      localize("D") + toolFormat.format(tool.diameterOffset) + " " +
      localize("L") + toolFormat.format(tool.lengthOffset)
    )
  );

  c3 += makeRow(makeColumn(d(localize("Type") + ": ") + v(getToolTypeName(tool.type))));
  c3 += makeRow(makeColumn(d(localize("Diameter") + ": ") + v(spatialFormat.format(tool.diameter) + getUnitSymbolAsString())));
  if (tool.cornerRadius) {
    c3 += makeRow(makeColumn(d(localize("Corner Radius") + ": ") + v(spatialFormat.format(tool.cornerRadius) + getUnitSymbolAsString())));
  }
  if (tool.taperAngle) {
    if (tool.isDrill()) {
      c3 += makeRow(makeColumn(d(localize("Tip Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
    } else {
      c3 += makeRow(makeColumn(d(localize("Taper Angle") + ": ") + v(taperFormat.format(tool.taperAngle) + "&deg;")));
    }
  }
  if (tool.isDrill() && (tool.threadPitch != 0)) {
    c3 += makeRow(makeColumn(d(localize("Pitch") + ": ") + v(pitchFormat.format(tool.threadPitch) + getUnitSymbolAsString() + "/" + localize("turn"))));
  }
  c3 += makeRow(makeColumn(d(localize("Length") + ": ") + v(spatialFormat.format(tool.bodyLength) + getUnitSymbolAsString())));
  c3 += makeRow(makeColumn(d(localize("Flutes") + ": ") + v(tool.numberOfFlutes)));
  if (tool.description) {
    c3 += makeRow(makeColumn(d(localize("Description") + ": ") + v(tool.description)));
  }
  if (tool.comment) {
    c3 += makeRow(makeColumn(d(localize("Comment") + ": ") + v(tool.comment)));
  }
  if (tool.holderDescription) {
    c3 += makeRow(makeColumn(d(localize("Holder") + ": ") + v(tool.holderDescription)));
  }
  if (tool.aggregateId) {
    c3 += makeRow(makeColumn(d(localize("Aggregate") + ": ") + v(tool.aggregateId)));
  }
  if (tool.manualToolChange) {
    c3 += makeRow(makeColumn(d(bold(localize("Manual tool change")))));
  }
  c3 += "</table>";

  var c4 = "";
  if (toolRenderer && properties.showToolImage) {
    var id = useToolNumber ? tool.number : (currentSection.getId() + 1);
    var path = "tool" + id + ".png";
    var width = 2.5 * 100;
    var height = 2.5 * 133;
    try {
      if (!exportedTools[id]) {
        toolRenderer.exportAs(path, "image/png", tool, width, height);
        exportedTools[id] = true; // do not export twice
      }
      c4 = "<table class=\"info\" cellspacing=\"0\">" +
        makeRow("<td class=\"image\"><img width=\"100px\" src=\"" + path + "\"/></td>") +
        "</table>";
    } catch(e) {
    }
  }

  write(
    "<tr class=\"info\">" +
      "<td valign=\"top\">" + c1 + "</td>" +
      "<td valign=\"top\">" + c2 + "</td>" +
      "<td valign=\"top\">" + c3 + "</td>" +
      (c4 ? "<td valign=\"top\" align=\"center\">" + c4 + "</td>" : "") +
    "</tr>"
  );

  if (properties.showPreviewImage) {
    var patternId = currentSection.getPatternId();
    var show = false;
    if (properties.forcePreview || !seenPatternIds[patternId]) {
      show = true;
      seenPatternIds[patternId] = true;
    }
    if (show && currentSection.hasParameter("autodeskcam:preview-name")) {
      var path = currentSection.getParameter("autodeskcam:preview-name");
      if (FileSystem.isFile(FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), path))) {
        var r2 = "<table class=\"info\" cellspacing=\"0\">" +
          makeRow("<td class=\"preview\"><img src=\"" + path + "\"/></td>") +
          "</table>";
        write(
          "<tr class=\"info\">" +
          "<td colspan=\"4\" valign=\"top\" align=\"center\">" + r2 + "</td>" +
          "</tr>"
        );
      }
    }
  }

  if (properties.showNotes && hasParameter("notes")) {
    var notes = getParameter("notes");
    if (notes) {
      write(
        "<tr class=\"notes\"><td valign=\"top\" colspan=\"4\">" +
        d(localize("Notes")) + ": <pre>" + getParameter("notes") +
        "</pre></td></tr>"
      );
    }
  }
  
  if (!isLastSection()) {
    write("<tr class=\"space\"><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>");
  }
  writeln("");
  writeln("");

  cachedParameters = {};
}

function formatCycleTime(cycleTime) {
  cycleTime = cycleTime + 0.5; // round up
  var seconds = cycleTime % 60 | 0;
  var minutes = ((cycleTime - seconds)/60 | 0) % 60;
  var hours = (cycleTime - minutes * 60 - seconds)/(60 * 60) | 0;
  if (hours > 0) {
    return subst(localize("%1h:%2m:%3s"), hours, minutes, seconds);
  } else if (minutes > 0) {
    return subst(localize("%1m:%2s"), minutes, seconds);
  } else {
    return subst(localize("%1s"), seconds);
  }
}

function writeTotals() {
  var zRange;
  var maximumFeed = 0;
  var maximumSpindleSpeed = 0;
  var cuttingDistance = 0;
  var rapidDistance = 0;
  var cycleTime = 0;

  var numberOfSections = getNumberOfSections();
  var currentTool;
  for (var i = 0; i < numberOfSections; ++i) {
    var section = getSection(i);

    if (is3D()) {
      var _zRange = section.getGlobalZRange();
      if (zRange) {
        zRange.expandToRange(_zRange);
      } else {
        zRange = _zRange;
      }
    }
    
    maximumFeed = Math.max(maximumFeed, section.getMaximumFeedrate());
    maximumSpindleSpeed = Math.max(maximumSpindleSpeed, section.getMaximumSpindleSpeed());
    cuttingDistance += section.getCuttingDistance();
    rapidDistance += section.getRapidDistance();
    cycleTime += section.getCycleTime();
    if (properties.toolChangeTime > 0) {
      var tool = section.getTool();
      if (currentTool != tool.number) {
        currentTool = tool.number;
        cycleTime += properties.toolChangeTime;
      }
    }
  }
  if (properties.rapidFeed > 0) {
    cycleTime += rapidDistance/properties.rapidFeed * 60;
  }
  totalCycleTime = cycleTime;

  writeln("<table class=\"sheet\" cellspacing=\"0\" align=\"center\">");
  write(makeRow("<th>" + localize("Total") + "</th>"));

  var c1 = "<table class=\"info\" cellspacing=\"0\">";
  var tools = getToolTable();
  c1 += makeRow(makeColumn(d(localize("Number Of Operations") + ": ") + v(getNumberOfSections())));
  var text = "";
  for (var i = 0; i < tools.getNumberOfTools(); ++i) {
    var tool = tools.getTool(i);
    if (i > 0) {
      text += " ";
    }
    text += bold(localize("T") + toolFormat.format(tool.number));
  }
  c1 += makeRow(makeColumn(d(localize("Number Of Tools") + ": ") + v(tools.getNumberOfTools())));
  c1 += makeRow(makeColumn(d(localize("Tools") + ": ") + v(text)));
  if (zRange) {
    c1 += makeRow(makeColumn(d(localize("Maximum Z") + ": ") + v(spatialFormat.format(zRange.getMaximum()) + getUnitSymbolAsString())));
    c1 += makeRow(makeColumn(d(localize("Minimum Z") + ": ") + v(spatialFormat.format(zRange.getMinimum()) + getUnitSymbolAsString())));
  }
  c1 += makeRow(makeColumn(d(localize("Maximum Feedrate") + ": ") + v(feedFormat.format(maximumFeed) + getFeedSymbolAsString())));
  c1 += makeRow(makeColumn(d(localize("Maximum Spindle Speed") + ": ") + v(rpmFormat.format(maximumSpindleSpeed) + localize("rpm"))));
  c1 += makeRow(makeColumn(d(localize("Cutting Distance") + ": ") + v(spatialFormat.format(cuttingDistance) + getUnitSymbolAsString())));
  if (properties.showRapidDistance) {
    c1 += makeRow(makeColumn(d(localize("Rapid Distance") + ": ") + v(spatialFormat.format(rapidDistance) + getUnitSymbolAsString())));
  }
  c1 += makeRow(makeColumn(d(localize("Estimated Cycle Time") + ": ") + v(formatCycleTime(cycleTime))));
  c1 += "</table>";

  write(
    "<tr class=\"info\">" +
      "<td valign=\"top\">" + c1 + "</td>" +
    "</tr>"
  );
  write("</table>");
  writeln("");
  writeln("");
}

function onClose() {
  if (properties.showOperations) {
    writeln("</table>");
  }
  
  // footer
  if (properties.showFooter) {
    write("<br>");
    write("<div class=\"footer\">");
    var src = findFile("../graphics/logo.png");
    var dest = "logo.png";
    if (FileSystem.isFile(src)) {
      FileSystem.copyFile(src, FileSystem.getCombinedPath(FileSystem.getFolderPath(getOutputPath()), dest));
      write("<img class=\"logo\" src=\"" + dest + "\"/>");
    }
    var now = new Date();
    var product = "Autodesk CAM";
    if (hasGlobalParameter("generated-by")) {
      product = getGlobalParameter("generated-by");
    }
    var productUrl = "http://cam.autodesk.com";
    if (product) {
      if ((product.indexOf("HSMWorks") == 0) || (product.indexOf("HSMXpress") == 0)) {
        productUrl = "http://www.hsmworks.com";
      }
    }
    write(localize("Generated by") + " <a href=\"" + productUrl + "\">" + product + "</a>" + " " + now.toLocaleDateString() + " " + now.toLocaleTimeString());
    write("</div");
  }
  write("</body>");
  write("</html>");
}

function quote(text) {
  var result = "";
  for (var i = 0; i < text.length; ++i) {
    var ch = text.charAt(i);
    switch (ch) {
    case "\\":
    case "\"":
      result += "\\";
    }
    result += ch;
  }
  return "\"" + result + "\"";
}

function onTerminate() {
  // add this to print automatically - you could print to XPS and PDF writer
  /*
  var device = "Microsoft XPS Document Writer";
  if (device) {
    executeNoWait("rundll32.exe", "mshtml.dll,PrintHTML " + quote(getOutputPath()) + quote(device), false, "");
  } else {
    executeNoWait("rundll32.exe", "mshtml.dll,PrintHTML " + quote(getOutputPath()), false, "");
  }
  */
}
