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

var colorIndex;
var colorSpan;

// TODO: make a method on Fractal?
function randomSimis(f, simis, start, offset, nColors, colorType) {
  for (var i = offset - 1; i >= 0; i--) {
    var cur = simis[offset + i];  // XXX
    cur.cx = gaussRand(0, 0.8, 4.0);
    cur.cy = gaussRand(0, 0.8, 4.0);
    cur.r = gaussRand(f.rMean, f.drMean, 3.0);
    cur.r2 = halfGaussRand(0, f.dr2Mean, 2.0);
    cur.a = gaussRand(0, Math.PI * 2, 4.0);
    cur.a2 = gaussRand(0, Math.PI * 2, 4.0);
    if (colorType == 0) {  // single color
      cur.colorindex = 0;
    } else if (colorType == 1) {  // gradient
      cur.colorindex = colorIndex;
      colorIndex += colorSpan;
    } else {  // random
      cur.colorindex = Math.floor(Math.random() * nColors);
    }
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
    var xy = Math.ceil(transformed.x * f.lx);
    f.buffer[i].push({
      x: f.lx + xd,
      y: f.ly - yd
    });
    if ((f.depth > 0) &&
        (Math.abs(transformed.x - xo) >= 16) &&
        (Math.abs(transformed.y - yo) >= 16)) {
      f.depth--;
      trace(f, transformed.x, transformed.y);
      f.depth++;
    }
  }
}

var alpha;

function drawFractal(f) {
  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    cur.ct = Math.cos(cur.a);
    cut.st = Math.sin(cur.a);
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

  colorindex++;
  if (colorindex >= nColors)
    colorindex = 0;

  for (var i = 0; i < f.nbSimi; i++) {
    var cur = f.components[i];
    var colornum = cur.colorindex + colorindex % ncolors;
    // glColor4f(colors[colornum].red, colors[colornum].green, colors[colornum].blue, alpha);
    // glBegin(GL_POINTS);
    for (var j = 0; j < pointNo[i]; j++) {
      // glVertex2i(f.buffer[i][j].x, f.buffer[i][j].y);
    }
    // glEnd();
  }
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

    s.cx = u0 * s1.cx + u1 * s2.cx + u2 * s3.cx + u3 * s4.cx,
    s.cy = u0 * s1.cy + u1 * s2.cy + u2 * s3.cy + u3 * s4.cy,
    s.r = u0 * s1.r + u1 * s2.r + u2 * s3.r + u3 * s4.r,
    s.r2 = u0 * s1.r2 + u1 * s2.r2 + u2 * s3.r2 + u3 * s4.r2,
    s.a = u0 * s1.a + u1 * s2.a + u2 * s3.a + u3 * s4.a,
    s.a2 = u0 * s1.a2 + u1 * s2.a2 + u2 * s3.a2 + u3 * s4.a2,
  }

  drawFractal(f);

  if (f.count >= 1000 / f.speed) {
    for (var i = 0; i < nbSimi; i++) {
      var s1 = f.components[i + nbSimi];
      var s2 = f.components[i + 2 * nbSimi];
      var s3 = f.components[i + 3 * nbSimi];
      var s4 = f.components[i + 4 * nbSimi];

      f.components[i + nbSimi] = s4;

      s2[i].cx = u0 * s1.cx + u1 * s2.cx + u2 * s3.cx + u3 * s4.cx,
      s2[i].cy = u0 * s1.cy + u1 * s2.cy + u2 * s3.cy + u3 * s4.cy,
      s2[i].r = u0 * s1.r + u1 * s2.r + u2 * s3.r + u3 * s4.r,
      s2[i].r2 = u0 * s1.r2 + u1 * s2.r2 + u2 * s3.r2 + u3 * s4.r2,
      s2[i].a = u0 * s1.a + u1 * s2.a + u2 * s3.a + u3 * s4.a,
      s2[i].a2 = u0 * s1.a2 + u1 * s2.a2 + u2 * s3.a2 + u3 * s4.a2,
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
}

document.addEventListener('DOMContentLoaded', init);
