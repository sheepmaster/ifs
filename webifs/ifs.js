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

var globalColorIndex = 0;  // XXX
var colorSpan = 50;

// TODO: make a method on Fractal?
function randomSimis(f, simis, start, offset, nColors, colorType) {
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
    x: xo * simi.ct - yo * simi.st + xx * simi.ct2 + simi.cx,
    y: yo * simi.st + yo * simi.ct + xx * simi.st2 + simi.cy
  }
}

// TODO: make a method on Fractal?
function trace(f, xo, yo) {
  for (var i = f.nbSimi - 1; i >= 0; i--) {
    var cur = f.components[f.nbSimi - i - 1];
    var transformed = transform(cur, xo, yo);
    var xd = Math.ceil(transformed.x * f.lx);
    var yd = Math.ceil(transformed.x * f.ly);
    f.buffer[i].push({
      x: f.lx + xd,
      y: f.ly - yd
    });
    if ((f.depth > 0) &&
        (Math.abs(transformed.x - xo) >= 1/256) &&
        (Math.abs(transformed.y - yo) >= 1/256)) {
      f.depth--;
      trace(f, transformed.x, transformed.y);
      f.depth++;
    }
  }
}

var alpha = 1;

var nColors = 200;
var colorIndex = 0;  // XXX

function drawFractal(f) {
  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    cur.ct = Math.cos(cur.a);
    cur.st = Math.sin(cur.a);
    cur.ct2 = Math.cos(cur.a2);
    cur.st2 = Math.sin(cur.a2);
  }

  for (var i = 0; i < f.buffer.length; i++) {
    f.buffer[i] = [];
  }

  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var xo = cur.cx;
    var yo = cur.cy;
    for (var j = 0; j < f.nbSimi; j++) {
      if (i == j)
        continue;

      var transformed = transform(f.components[j], xo, yo);
      trace(f, transformed.x, transformed.y);
    }
  }

  colorIndex++;
  if (colorIndex >= nColors)
    colorIndex = 0;

  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var colorNum = cur.colorIndex + colorIndex % nColors;
    // glColor4f(colors[colorNum].red, colors[colorNum].green, colors[colorNum].blue, alpha);
    // glBegin(GL_POINTS);
    for (var j = 0; j < f.buffer[i].length; j++) {
      // console.log(f.buffer[i][j].x, f.buffer[i][j].y);
      // glVertex2i(f.buffer[i][j].x, f.buffer[i][j].y);
    }
    // glEnd();
  }
}

var simiColor = 1;

function initIfs(f, width, height) {
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
  f.maxPt = Math.pow(f.nbSimi - 1, f.depth + 1);

  f.buffer = [];  // TODO: length f.nbSimi
  for (var i = 0; i < f.nbSimi; i++) {
    f.buffer[i] = [];  // TODO: length f.maxPt
  }

  f.speed = 6;
  f.count = 0;
  f.lx = (width - 1) / 2;
  f.ly = (height - 1) / 2;

  f.components = [];  // TODO: length 5 * f.nbSimi
  randomSimis(f, f.components, 0, 5 * f.nbSimi, nColors, simiColor);
}

function drawIfs(f) {
  var u = f.count * f.speed / 1000;
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
    s.r = u0 * s1.r + u1 * s2.r + u2 * s3.r + u3 * s4.r;
    s.r2 = u0 * s1.r2 + u1 * s2.r2 + u2 * s3.r2 + u3 * s4.r2;
    s.a = u0 * s1.a + u1 * s2.a + u2 * s3.a + u3 * s4.a;
    s.a2 = u0 * s1.a2 + u1 * s2.a2 + u2 * s3.a2 + u3 * s4.a2;
  }

  drawFractal(f);

  if (f.count >= 1000 / f.speed) {
    for (var i = 0; i < nbSimi; i++) {
      var s1 = f.components[i + nbSimi];
      var s2 = f.components[i + 2 * nbSimi];
      var s3 = f.components[i + 3 * nbSimi];
      var s4 = f.components[i + 4 * nbSimi];

      f.components[i + nbSimi] = s4;

      s2[i].cx = u0 * s1.cx + u1 * s2.cx + u2 * s3.cx + u3 * s4.cx;
      s2[i].cy = u0 * s1.cy + u1 * s2.cy + u2 * s3.cy + u3 * s4.cy;
      s2[i].r = u0 * s1.r + u1 * s2.r + u2 * s3.r + u3 * s4.r;
      s2[i].r2 = u0 * s1.r2 + u1 * s2.r2 + u2 * s3.r2 + u3 * s4.r2;
      s2[i].a = u0 * s1.a + u1 * s2.a + u2 * s3.a + u3 * s4.a;
      s2[i].a2 = u0 * s1.a2 + u1 * s2.a2 + u2 * s3.a2 + u3 * s4.a2;
    }

    randomSimis(f, f.components, 3 * nbSimi, nbSimi, nColors, simiColor);
    randomSimis(f, f.components, 4 * nbSimi, nbSimi, nColors, simiColor);  // XXX

    f.count = 0;
  } else {
    f.count++;
  }
}

function init() {
  var canvas = document.getElementById('canvas');
  var gl = canvas.getContext('webgl') ||
           canvas.getContext('experimental-webgl');

  gl.clearColor(0.0, 0.0, 0.0, 1.0);  // Set clear color to black, fully opaque
  gl.enable(gl.DEPTH_TEST);           // Enable depth testing
  gl.depthFunc(gl.LEQUAL);            // Near things obscure far things
  // Clear the color as well as the depth buffer.
  gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);

  var f = {};
  initIfs(f, canvas.width, canvas.height);
  drawIfs(f);
}

document.addEventListener('DOMContentLoaded', init);
