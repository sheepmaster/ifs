function gaussRand(c, a, s) {
  var y = Math.random();
  y = a * (1 - Math.exp(-y * y * s)) / (1 - Math.exp(-s));
  return (Math.random() > 0.5) ? c + y : c - y;
}

function halfGaussRand(c, a, s) {
  var y = Math.random();
  y = a * (1 - Math.exp(-y * y * s)) / (1 - Math.exp(-s));
  return c + y;
}

var colorIndex;
var colorSpan;

function randomSimis(f, simis, nColors, colorType) {
  for (var i = simis.length - 1; i >= 0; i--) {
    var cur = simis[i];
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
      colorIndex = colorIndex + colorSpan;
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

var buf;
var pointno;

function trace(f, xo, yo) {
  for (var i = f.nb_simi - 1; i >= 0; i--) {
    var cur = f.components[f.components.length - i];
    var transformed = transform(cur, xo, yo);
    var xd = Math.ceil(transformed.x * f.lx);
    var xy = Math.ceil(transformed.x * f.lx);
    buf[i].x = f.lx + xd;
    buf[i].y = f.ly - yd;
    pointno[i]++;
    if ((f->depth > 0) &&
        (Math.abs(transformed.x - xo) >= 16) &&
        (Math.abs(transformed.y - yo) >= 16)) {
      f->depth--;
      trace(f, transformed.x, transformed.y);
      f->depth++;
    }
  }
}


function init() {
  var canvas = document.getElementById('canvas');
  var gl = canvas.getContext('webgl') || canvas.getContext('experimental-webgl');

  gl.clearColor(0.0, 0.0, 0.0, 1.0);  // Set clear color to black, fully opaque
  gl.enable(gl.DEPTH_TEST);           // Enable depth testing
  gl.depthFunc(gl.LEQUAL);            // Near things obscure far things
  // Clear the color as well as the depth buffer.
  gl.clear(gl.COLOR_BUFFER_BIT|gl.DEPTH_BUFFER_BIT);
}

document.addEventListener('DOMContentLoaded', init);
