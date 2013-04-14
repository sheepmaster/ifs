/*
 * Copyright (c) 1997 by Massimino Pascal <Pascal.Massimon@ens.fr>
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted,
 * provided that the above copyright notice appear in all copies and that
 * both that copyright notice and this permission notice appear in
 * supporting documentation.
 *
 * This file is provided AS IS with no warranties of any kind.  The author
 * shall have no liability with respect to the infringement of copyrights,
 * trade secrets or any patents by this file or any part thereof.  In no
 * event will the author be liable for any lost revenue or profits or
 * other special, indirect and consequential damages.
 *
 * If this mode is weird and you have an old MetroX server, it is buggy.
 * There is a free SuSE-enhanced MetroX X server that is fine.
 *
 * When shown ifs, Diana Rose (4 years old) said, "It looks like dancing."
 */

"use strict";

var context;

var gl;   // The webgl context, to be initialized in init().
var prog; // Identifies the webgl program.
var vertexAttributeBuffer;    // Identifies the databuffer where vertex coords are stored.
var vertexAttributeLocation;  // Identifies the vertex attribute variable in the shader program.
var pointSizeUniformLocation; // Identifies the uniform that controls the size of points.
var antialiasedLoc;           // Identifies the uniform that determines whether points are antialiased.
var colorLoc;
var transformUniformLocation; // Identifies the coordinate matrix uniform variable.

/**
 * Applies a coordinate transformation to the webgl context by setting the value
 * of the coordinateTransform uniform in the shader program.  The canvas will
 * display the region of the xy-plane with x ranging from xmin to xmax and y
 * ranging from ymin to ymax.  If ignoreAspect is true, these ranges will fill
 * the canvas.  If ignoreAspect is missing or is false, one of the x or y
 * ranges will be expanded, if necessary, so that the aspect ratio is preserved.
 */
function coordinateTransform(xmin, xmax, ymin, ymax, ignoreAspect) {
  if (!ignoreAspect) {
    var displayAspect = gl.canvas.height / gl.canvas.width;
    var requestedAspect = Math.abs((ymax-ymin)/(xmax-xmin));
    if (displayAspect > requestedAspect) {
      var excess= (ymax-ymin) * (displayAspect/requestedAspect - 1);
      ymin -= excess/2;
      ymax += excess/2;
    }
    else if (displayAspect < requestedAspect) {
      var excess = (xmax-xmin) * (requestedAspect/displayAspect - 1);
      xmin -= excess/2;
      xmax += excess/2;
    }
  }
  var coordTrans = [
    2/(xmax-xmin),           0,                       0,
    0,                       2/(ymax-ymin),           0,
    -1 - 2*xmin/(xmax-xmin), -1 - 2*ymin/(ymax-ymin), 1
  ];
  gl.uniformMatrix3fv(transformUniformLocation, false, coordTrans);
}

function nRand(n) {
  return Math.floor(Math.random() * n);
}

function gaussRand(c, a, s) {
  var y = Math.random();
  y = a * (1 - Math.exp(-y * y * s)) / (1 - Math.exp(-s));
  return (Math.random() > 0.5) ? c + y : c - y;
}

function halfGaussRand(c, a, s) {
  var y = Math.random();
  y = a * (1 - Math.exp(-y * y * s)) / (1 - Math.exp(-s));
  return c + y;  // TODO: unify with gaussRand()
}

function HSVToRGB(h, s, v) {
  if(s == 0) {
    // achromatic (grey)
    return [v, v, v];
  }
  h *= 6;      // sector 0 to 5
  var i = Math.floor(h);
  var f = h - i;      // factorial part of h
  var p = v * (1 - s);
  var q = v * (1 - s * f);
  var t = v * (1 - s * (1 - f));
  switch (i) {
    case 0:
      return [v, t, p];
    case 1:
      return [q, v, p];
    case 2:
      return [p, v, t];
    case 3:
      return [p, q, v];
    case 4:
      return [t, p, v];
    case 5:
      return [v, p, q];
    default:
      throw new Error();
  }
}

var globalColorIndex = 0;  // XXX
var nColors = 200;
var colorSpan = nColors/50;

// TODO: make a method on Fractal?
function randomSimis(simis, start, offset, nColors, colorType) {
  for (var i = offset - 1; i >= 0; i--) {
    var cur = {};
    cur.cx = gaussRand(0, 0.8, 4.0);
    cur.cy = gaussRand(0, 0.8, 4.0);
    cur.r = gaussRand(f.rMean, f.drMean, 3.0);
    cur.r2 = halfGaussRand(0, f.dr2Mean, 2.0);
    cur.a = gaussRand(0, Math.PI * 2, 4.0);
    cur.a2 = gaussRand(0, Math.PI * 2, 4.0);
    if (colorType == 0) {  // single color
      cur.colorIndex = 0;
    } else if (colorType == 1) {  // gradient
      cur.colorIndex = globalColorIndex;
      globalColorIndex += colorSpan;
    } else {  // random
      cur.colorindex = nRand(nColors);
    }
    simis[start + i] = cur;
  }
}

function transform(simi, xo, yo) {
  xo = xo - simi.cx;
  xo = xo * simi.r;
  yo = yo - simi.cy;
  yo = yo * simi.r;

  var xx = xo - simi.cx;
  xx = xx * simi.r2;
  var yy = -yo - simi.cy;
  yy = yy * simi.r2;

  return {
    x: xo * simi.ct - yo * simi.st + xx * simi.ct2 - yy * simi.st2 + simi.cx,
    y: xo * simi.st + yo * simi.ct + xx * simi.st2 + yy * simi.ct2 + simi.cy
  };
}

var f = {};
// TODO: make a method on Fractal?
function trace(xo, yo) {
  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var transformed = transform(cur, xo, yo);
    f.buffer[i][2 * f.index[i]] = (1 + transformed.x) * f.lx;
    f.buffer[i][2 * f.index[i] + 1] = (1 + transformed.y) * f.ly;
    f.index[i]++;
    if ((f.depth > 0) &&
        (Math.abs(transformed.x - xo) >= 1/256) &&
        (Math.abs(transformed.y - yo) >= 1/256)) {
      f.depth--;
      trace(transformed.x, transformed.y);
      f.depth++;
    }
  }
}

var alpha = 0.25;

var colorIndex = 0;  // XXX

function randomColors(nColors) {
  var s = Math.random() * 0.4 + 0.6;
  var v = Math.random() * 0.4 + 0.6;
  var dh = 1.0/nColors;
  var colors = [];
  for (var i = 0; i < nColors; i++) {
    colors.push(HSVToRGB(i * dh, s, v));
  }
  return colors;
}

function drawFractal() {
  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    cur.ct = Math.cos(cur.a);
    cur.st = Math.sin(cur.a);
    cur.ct2 = Math.cos(cur.a2);
    cur.st2 = Math.sin(cur.a2);
  }

  for (var i = 0; i < f.buffer.length; i++) {
    f.index[i] = 0;
  }

  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var xo = cur.cx;
    var yo = cur.cy;
    for (var j = 0; j < f.nbSimi; j++) {
      if (i == j)
        continue;

      var transformed = transform(f.components[j], xo, yo);
      trace(transformed.x, transformed.y);
    }
  }

  colorIndex++;
  if (colorIndex >= nColors)
    colorIndex = 0;

  drawWebGL();
  // drawCanvas();
}

function drawWebGL() {
  gl.clearColor(0,0,0,1);
  gl.clear(gl.COLOR_BUFFER_BIT);
  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var colorNum = (cur.colorIndex + colorIndex) % nColors;

    gl.uniform3fv(colorLoc, colors[colorNum]);
    gl.bindBuffer(gl.ARRAY_BUFFER, vertexAttributeBuffer);
    gl.bufferData(gl.ARRAY_BUFFER, f.buffer[i], gl.DYNAMIC_DRAW);
    gl.vertexAttribPointer(vertexAttributeLocation, 2, gl.FLOAT, false, 0, 0);
    gl.enableVertexAttribArray(vertexAttributeLocation);
    gl.drawArrays(gl.POINTS, 0, f.index[i]);
  }
}

function drawCanvas() {
  // context.fillRect(0, 0, width, height);
  var bufferData = context.createImageData(width, height);
  for (var i = 0; i < height * width; i++) {
    bufferData.data[4 * i + 3] = 255;
  }
  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var colorNum = cur.colorIndex + colorIndex % nColors;
    // glColor4f(colors[colorNum].red, colors[colorNum].green, colors[colorNum].blue, alpha);
    // glBegin(GL_POINTS);
    for (var j = 0; j < f.index[i]; j++) {
      var x = Math.round(f.buffer[i][2 * j]);
      var y = Math.round(f.buffer[i][2 * j + 1]);
      var index = 4 * (y * width + x) + 1;
      bufferData.data[index] = 255 * alpha + bufferData.data[index] * (1-alpha);
      // console.log(.x, f.buffer[i][j].y);
      // glVertex2i(f.buffer[i][j].x, f.buffer[i][j].y);
    }
    // glEnd();
  }
  context.putImageData(bufferData, 0, 0);
}

var simiColor = 1;

var width;
var height;

var colors;

function initIfs() {
  var r = nRand(4) + 2;  // Number of centers
  switch(r) {
    case 2: {
      f.depth = 11;
      f.rMean = 0.7;
      f.drMean = 0.3;
      f.dr2Mean = 0.4;
      break;
    }
    case 3: {
      f.depth = 7;
      f.rMean = 0.6;
      f.drMean = 0.4;
      f.dr2Mean = 0.3;
      break;
    }
    case 4: {
      f.depth = 5;
      f.rMean = 0.5;
      f.drMean = 0.4;
      f.dr2Mean = 0.3;
      break;
    }
    case 5: {
      f.depth = 4;
      f.rMean = 0.5;
      f.drMean = 0.4;
      f.dr2Mean = 0.3;
      break;
    }
    default: {
      throw new Error('Invalid number of centers: ' + r);
    }
  }
  f.nbSimi = r;
  f.maxPt = Math.pow(f.nbSimi, f.depth + 2);

  f.buffer = new Array(f.nbSimi);
  f.index = new Array(f.nbSimi);
  for (var i = 0; i < f.buffer.length; i++) {
    var buf = new ArrayBuffer(8 * f.maxPt);
    f.buffer[i] = new Float32Array(buf);
    f.index[i] = 0;
  }

  f.lx = (width - 1) / 2;
  f.ly = (height - 1) / 2;

  f.components = [];  // TODO: length 5 * f.nbSimi
  randomSimis(f.components, 0, 5 * f.nbSimi, nColors, simiColor);

  colors = randomColors(nColors);

  initWebGL();
}

function initWebGL() {
  gl = createWebGLContext('canvas');
  var vertexShaderSource = getElementText('vshader');
  var fragmentShaderSource = getElementText('fshader');
  prog = createProgram(gl,vertexShaderSource,fragmentShaderSource);
  gl.useProgram(prog);
  vertexAttributeLocation = gl.getAttribLocation(prog, 'vertexCoords');
  transformUniformLocation = gl.getUniformLocation(prog, 'coordinateTransform');
  antialiasedLoc = gl.getUniformLocation(prog, 'antialiased');
  colorLoc = gl.getUniformLocation(prog, 'color');
  gl.uniform1f(antialiasedLoc, 1);
  coordinateTransform(0, width, height, 0);  // Lets me use standard pixel coords.
  vertexAttributeBuffer = gl.createBuffer();
  pointSizeUniformLocation = gl.getUniformLocation(prog, 'pointSize');
  var pointSizeRange = gl.getParameter(gl.ALIASED_POINT_SIZE_RANGE);
  gl.uniform1f(pointSizeUniformLocation, 2);
  gl.blendFuncSeparate(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA, gl.ZERO, gl.ONE);
  gl.enable(gl.BLEND);
}

var speed = 1000000 / (6 * 30);  // Time interval in ms before we create a new transform.
var lastTime = Date.now();

function drawIfs() {
  var now = Date.now();
  var u = (now - lastTime) / speed;
  var uu = u * u;
  var v = 1 - u;
  var vv = v * v;
  var u0 = vv * v;
  var u1 = 3 * vv * u;
  var u2 = 3 * v * uu;
  var u3 = u * uu;

  var nbSimi = f.nbSimi;

  for (var i = 0; i < nbSimi; i++) {
    var s = f.components[i];
    var s1 = f.components[i + nbSimi];
    var s2 = f.components[i + 2 * nbSimi];
    var s3 = f.components[i + 3 * nbSimi];
    var s4 = f.components[i + 4 * nbSimi];

    s.cx = u0 * s1.cx + u1 * s2.cx + u2 * s3.cx + u3 * s4.cx;
    s.cy = u0 * s1.cy + u1 * s2.cy + u2 * s3.cy + u3 * s4.cy;
    s.r  = u0 * s1.r  + u1 * s2.r  + u2 * s3.r  + u3 * s4.r;
    s.r2 = u0 * s1.r2 + u1 * s2.r2 + u2 * s3.r2 + u3 * s4.r2;
    s.a  = u0 * s1.a  + u1 * s2.a  + u2 * s3.a  + u3 * s4.a;
    s.a2 = u0 * s1.a2 + u1 * s2.a2 + u2 * s3.a2 + u3 * s4.a2;
  }

  drawFractal();

  if (u >= 1.0) {
    for (var i = 0; i < nbSimi; i++) {
      var s1 = f.components[i + nbSimi];
      var s2 = f.components[i + 2 * nbSimi];
      var s3 = f.components[i + 3 * nbSimi];
      var s4 = f.components[i + 4 * nbSimi];

      f.components[i + nbSimi] = s4;

      s2.cx = 2 * s4.cx - s3.cx;
      s2.cy = 2 * s4.cy - s3.cy;
      s2.r  = 2 * s4.r  - s3.r;
      s2.r2 = 2 * s4.r2 - s3.r2;
      s2.a  = 2 * s4.a  - s3.a;
      s2.a2 = 2 * s4.a2 - s3.a2;
    }

    randomSimis(f.components, 3 * nbSimi, nbSimi, nColors, simiColor);
    randomSimis(f.components, 4 * nbSimi, nbSimi, nColors, simiColor);  // XXX

    lastTime = now;
  }

  window.requestAnimationFrame(drawIfs);
}

function init() {
  var canvas = document.getElementById('canvas');
  // context = canvas.getContext('2d');

  width = canvas.width = canvas.clientWidth;
  height = canvas.height = canvas.clientHeight;

  initIfs();
  drawIfs();
}

document.addEventListener('DOMContentLoaded', init);
