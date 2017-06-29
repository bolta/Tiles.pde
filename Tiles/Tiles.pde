/** 連続的に変化する色を提供するインタフェース */
interface ColorGenerator {
  color getColor();
  void next();
}

/** ランダムウォークで変化する色を提供する */
class DefaultColorGenerator implements ColorGenerator {
  private float r = random(256);
  private float g = random(256);
  private float b = random(256);

  private final float maxChange;
  private final int times;

  /**
   * @param maxChange 1 回のステップで RGB の各成分が変化する幅の最大値
   * @param times 1 回のステップで内部的に何回分のステップを行うか
   */
  public DefaultColorGenerator(float maxChange, int times) {
    this.maxChange = maxChange;
    this.times = times;
  }

  public DefaultColorGenerator(float maxChange) {
    this(maxChange, 1);
  }

  public color getColor() {
    return color(this.r, this.g, this.b);
  }

  public void next() {
    for (int i=0 ; i<times ; ++i) {
      this.r = adjust(this.r + random(-this.maxChange, this.maxChange));
      this.g = adjust(this.g + random(-this.maxChange, this.maxChange));
      this.b = adjust(this.b + random(-this.maxChange, this.maxChange));
    }
  }
  
  protected float adjust(float colorComponent) {
    return limit(colorComponent);
  }
}

float limit(float min, float value, float max) {
  return value < min ? min : value > max ? max : value;
}

float limit(float value) {
  return limit(0, value, 255.9);
}

/** 0 を下回ったら 255、255 を上回ったら 0 にする */
float wrap(float value) {
  return 256 * (value / 256 - floor(value / 256));
}

color multiply(float ratio, color c) {
  return color(
      limit(ratio * red(c)),
      limit(ratio * green(c)),
      limit(ratio * blue(c))); 
}

/** 与えられた色を使って描画することが可能な「図形」のインタフェース */
interface Shape {
  void paint(ColorGenerator col);
}

/** 単色の矩形（縁取りあり） */
class MonotoneRect implements Shape {
  private final int x, y;
  private final int rectWidth, rectHeight;
  public MonotoneRect(int x, int y, int rectWidth, int rectHeight) {
    this.x = x;
    this.y = y;
    this.rectWidth = rectWidth;
    this.rectHeight = rectHeight;
  }
  
  public void paint(ColorGenerator col) {
    pushStyle();
    try {
      color c = col.getColor();
      fill(this.getFillColor(c));
      stroke(this.getStrokeColor(c));
      rect(this.x, this.y, this.rectWidth, this.rectHeight);
    } finally {
      popStyle();
    }

    col.next();
  }
  
  protected color getFillColor(color c) {
    return c;
  }
  
  protected color getStrokeColor(color c) {
    return multiply(0.75, c);
  }
}

/**
 * 格子状に区切られた矩形。
 * createChildShape() をオーバーライドすることで、格子の各セルに別の Shape を入れ子にすることができる
 */
abstract class Matrix implements Shape {
  private final int left, top;
  private final int tileWidth, tileHeight;
  private final int columnCount, rowCount;

  protected Matrix(int left, int top, int canvasWidth, int canvasHeight,
      int tileWidth, int tileHeight) {
    this.left = left;
    this.top = top;
    this.tileWidth = tileWidth;
    this.tileHeight = tileHeight;
    this.columnCount = ceil((float) canvasWidth / tileWidth);
    this.rowCount = ceil((float) canvasHeight / tileHeight);
  }

  protected void paint(int xIdx, int yIdx, ColorGenerator col) {
    Shape child = createChildShape(xIdx, yIdx,
        this.left + xIdx * this.tileWidth, this.top + yIdx * this.tileHeight,
        this.tileWidth, this.tileHeight);
    child.paint(col);
  }

  // override me
  protected Shape createChildShape(int xIdx, int yIdx,
      int x, int y, int tileWidth, int tileHeight) {
    return new MonotoneRect(x, y, tileWidth, tileHeight);
  }

  public float getTileWidth() { return this.tileWidth; }
  public float getTileHeight() { return this.tileHeight; }
  public int getColumnCount() { return this.columnCount; }
  public int getRowCount() { return this.rowCount; }
}

/** 格子を左から右、上から下の順で塗る */
class LToR extends Matrix {
  public LToR(int left, int top, int canvasWidth, int canvasHeight,
      int tileWidth, int tileHeight) {
    super(left, top, canvasWidth, canvasHeight, tileWidth, tileHeight);
  }
  
  public void paint(ColorGenerator col) {
    int rows = this.getRowCount();
    int cols = this.getColumnCount();
    for (int y=0 ; y<rows ; ++y) {
      for (int x=0 ; x<cols ; ++x) {
        this.paint(x, y, col);
      }
    }
  }
}

/** 格子を左上から始まる右上がりの斜行で塗る */
class Diagonal extends Matrix {
  private int x = 0, y = 0;
  
  public Diagonal(int left, int top, int canvasWidth, int canvasHeight,
      int tileWidth, int tileHeight) {
    super(left, top, canvasWidth, canvasHeight, tileWidth, tileHeight);
  }

  public void paint(ColorGenerator col) {
    do {
      paint(this.x, this.y, col);
    } while (this.next());
  }

  private boolean next() {
//    println(this.x + ", " + this.y);
    if (this.x >= this.getColumnCount() - 1
        && this.y >= this.getRowCount() - 1)
      return false;

    ++ this.x; -- this.y;
    if (this.x < this.getColumnCount() && this.y >= 0)
      return true;
    
//    println("wrap");
    
    ++ this.y;
//    println("=> " + this.x + ", " + this.y);
    int offsetFromLeft = this.x;
    int offsetFromBottom = this.getRowCount() - 1 - this.y;
    if (offsetFromLeft < offsetFromBottom) {
      this.x = 0;
      this.y += offsetFromLeft;
    } else {
      this.x -= offsetFromBottom;
      this.y = this.getRowCount() - 1;
    }

    return true;
  }
}

/**
 * 容器の中に粉を撒いて積もらせていくように、下から上に向かって塗る。
 * 撒き方は getNextX() をオーバーライドして定義する
 */
abstract class AbstractScattering extends Matrix {
  protected int x, y;
  private final int[] heights;
  private int paintCount = 0;
  
  protected AbstractScattering(int left, int top, int canvasWidth, int canvasHeight,
      int tileWidth, int tileHeight) {
    super(left, top, canvasWidth, canvasHeight, tileWidth, tileHeight);
    this.heights = new int[this.getColumnCount()];
    this.next();
  }

  public void paint(ColorGenerator col) {
    do {
      paint(this.x, this.y, col);
    } while (this.next());
  }
  
  private  boolean next() {
    if (this.paintCount >= this.getColumnCount() * this.getRowCount())
      return false;
    
    int nextX = this.x;
    do {
      nextX = this.getNextX(nextX);
    } while (this.heights[nextX] >= this.getRowCount());
    ++ this.heights[nextX];
    this.x = nextX;
    this.y = this.getRowCount() - this.heights[nextX];
    
    ++ this.paintCount;
    
    return true;
  }

  /**
   * 今回塗った x 座標から次の x 座標を得る
   */
  protected abstract int getNextX(int curX);
} 

/** 色を上から撒いていく。x 座標はランダムに変化する */
class Scattering0 extends AbstractScattering {
  public Scattering0(int left, int top, int canvasWidth, int canvasHeight,
      int tileWidth, int tileHeight) {
    super(left, top, canvasWidth, canvasHeight, tileWidth, tileHeight);
  }
  protected int getNextX(int curX) {
    return int(random(this.getColumnCount()));
  }
}

/** 色を上から撒いていく。x 座標は前回から ±1 の範囲で変化する（山ができやすい） */
class Scattering1 extends AbstractScattering {
  public Scattering1(int left, int top, int canvasWidth, int canvasHeight,
      int tileWidth, int tileHeight) {
    super(left, top, canvasWidth, canvasHeight, tileWidth, tileHeight);
  }
  protected int getNextX(int curX) {
    return (curX + int(random(3)) - 1 + this.getColumnCount())
        % this.getColumnCount();
  }
}

void saveImage() {
  save(width + "x" + height + "_" + System.currentTimeMillis() + ".png");
}

void setup() {
//  size(displayWidth, displayHeight);
//  ColorGenerator col = new DefaultColorGenerator(1, 128);
//  Shape shape = new LToR(0, 0, width, height, 32, 32) {
//    protected Shape createChildShape(int xIdx, int yIdx,
//        int x, int y, int tileWidth, int tileHeight) {
//      return new LToR(x, y, tileWidth, tileHeight, 4, 4);
//    }
//  };

//  ColorGenerator col = new DefaultColorGenerator(1, 128);
//  Shape shape = new LToR(0, 0, width, height, 128, 128) {
//    protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//      return new LToR(x, y, tileWidth, tileHeight, 16, 16) {
//        protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//          return new MonotoneRect(x, y, tileWidth, tileHeight) {
//            @Override protected color getStrokeColor(color c) { return multiply(0.875, c); } 
//          };
//        }
//      };
//    }
//  };
//  shape.paint(col);

  size(1920, 1080);

//  ColorGenerator col = new DefaultColorGenerator(1, 2); // { protected float adjust(float c) { return wrap(c%256.0); } };
//  Shape shape =
//  new Diagonal(0, 0, width, height, 128, 128) {
//    protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//      return new Diagonal(x, y, tileWidth, tileHeight, 64, 64) {
//        protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//          return new Diagonal(x, y, tileWidth, tileHeight,32, 32) {
//            protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//              return new Diagonal(x, y, tileWidth, tileHeight, 16, 16) {
//                protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//                  return new Diagonal(x, y, tileWidth, tileHeight, 8, 8) {
//                    protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//                      return new Diagonal(x, y, tileWidth, tileHeight,  4,  4) {
//                        protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//                          return new Diagonal(x, y, tileWidth, tileHeight,  2,  2) {
//                            protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//                              return new Diagonal(x, y, tileWidth, tileHeight,  1,  1) {
//                                protected Shape createChildShape(int xIdx, int yIdx, int x, int y, int tileWidth, int tileHeight) {
//                                  return new MonotoneRect(x, y, tileWidth, tileHeight) {
//                                    @Override protected color getStrokeColor(color c) { return c; /*multiply(0.875, c);*/ } 
//                                  };
//                                }
//                              };
//                            }
//                          };
//                        }
//                      };
//                    }
//                  };
//                }
//              };
//            }
//          };
//        }
//      };
//    }
//  };

  ColorGenerator col = new DefaultColorGenerator(8, 4); // { protected float adjust(float c) { return wrap(c%256.0); } };
  Shape shape = new LToR(0, 0, width, height, 128, 8);

//  size(220, 220);
//  ColorGenerator col = new DefaultColorGenerator(1, 8); // { protected float adjust(float c) { return wrap(c%256.0); } };
//  Shape shape = new Diagonal(0, 0, width, height, 2, 2) {
//    protected Shape createChildShape(int xIdx, int yIdx,
//        int x, int y, int tileWidth, int tileHeight) {
//      return new MonotoneRect(x, y, tileWidth, tileHeight) {
//        protected color getStrokeColor(color c) {
//          return c;
//        }
//      };
//    }
//  };

//  size(displayWidth, displayHeight);
//  size(1366, 768);
//  ColorGenerator col = new DefaultColorGenerator(1, 2);
//  Shape shape = new Diagonal(0, 0, width, height, width/20, height/4) {
//    protected Shape createChildShape(int xIdx, int yIdx,
//        int x, int y, int tileWidth, int tileHeight) {
//      return new LToR(x, y, tileWidth, tileHeight, 4, 4);
//    }
//  };

//  size(displayWidth, displayHeight);
//  ColorGenerator col = new DefaultColorGenerator(1, 2);
//  Shape shape = new Scattering0(0, 0, width, height, 4, 16) {
////    protected Shape createChildShape(int xIdx, int yIdx,
////        int x, int y, int tileWidth, int tileHeight) {
////      return new Diagonal(x, y, tileWidth, tileHeight, 1, 1);
////    }
//  };
////  new Diagonal(0, 0, width, height, width/20, height/4) {
////    protected Shape createChildShape(int xIdx, int yIdx,
////        int x, int y, int tileWidth, int tileHeight) {
////      return new LToR(x, y, tileWidth, tileHeight, 4, 4);
////    }
////  };

//  size(256, 256);
//  ColorGenerator col = new DefaultColorGenerator(4, 16);
//  Shape shape = new Diagonal(0, 0, width, height, 16, 16) {
//    protected Shape createChildShape(int xIdx, int yIdx,
//        int x, int y, int tileWidth, int tileHeight) {
//      return new MonotoneRect(x, y, tileWidth, tileHeight) {
//        protected color getStrokeColor(color c) {
//          return multiply(0.875, c);
//        }
//      };
//    }
//  };
  
//  size(1440, 900);
//  size(displayWidth, displayHeight);
//  ColorGenerator col = new DefaultColorGenerator(1, 1);
////  Shape shape = new LToR(0, 0, width, height, 1, 4) {
//  Shape shape = new LToR(0, 0, width, height, width/16, height) {
//    protected Shape createChildShape(int xIdx, int yIdx,
//        int x, int y, int tileWidth, int tileHeight) {
//      return new Scattering0(x, y, tileWidth, tileHeight, 4, 4) {
//        protected Shape createChildShape(int xIdx, int yIdx,
//            int x, int y, int tileWidth, int tileHeight) {
//          return new MonotoneRect(x, y, tileWidth, tileHeight) {
////            protected color getStrokeColor(color c) {
////              return multiply(1.125, c);
////            }
//          };
//        }
//      };
//    }
//  };
  shape.paint(col);

  saveImage();
}