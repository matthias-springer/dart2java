package tracer;

public class BenchmarkBase extends dart._runtime.base.DartObject
{
    public static dart._runtime.types.simple.InterfaceTypeInfo dart2java$typeInfo = new dart._runtime.types.simple.InterfaceTypeInfo("file:///usr/local/google/home/springerm/ddc-java/gen/codegen_tests/tracer.dart", "BenchmarkBase");
    static {
      tracer.BenchmarkBase.dart2java$typeInfo.superclass = new dart._runtime.types.simple.InterfaceTypeExpr(dart._runtime.helpers.ObjectHelper.dart2java$typeInfo);
    }
    public java.lang.String name;
    public static int iters = 1000;
  
    public BenchmarkBase(java.lang.String name)
    {
      super((dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker) null);
      this._constructor(name);
    }
    public BenchmarkBase(dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker arg)
    {
      super(arg);
    }
  
    protected void _constructor(java.lang.String name)
    {
      this.iters = 1000;
      this.name = name;
      super._constructor();
    }
    public void run()
    {
      
    }
    public void warmup()
    {
      this.run();
    }
    public void exercise()
    {
      for (int i = 0; dart._runtime.helpers.IntegerHelper.operatorLess(i, tracer.BenchmarkBase.iters); i = dart._runtime.helpers.IntegerHelper.operatorPlus(i, 1))
      {
        this.run();
      }
    }
    public void setup()
    {
      
    }
    public void teardown()
    {
      
    }
    public java.lang.Double measureForWarumup(int timeMinimum)
    {
      int time = 0;
      int iter = 0;
      dart.core.Stopwatch watch = new dart.core.Stopwatch();
      watch.start();
      int elapsed = 0;
      while (dart._runtime.helpers.IntegerHelper.operatorLess(elapsed, timeMinimum))
      {
        this.warmup();
        elapsed = watch.getElapsedMilliseconds();
        iter = dart._runtime.helpers.IntegerHelper.operatorPlus(iter, 1);
      }
      return dart._runtime.helpers.DoubleHelper.operatorDivide(dart._runtime.helpers.DoubleHelper.operatorDivide(dart._runtime.helpers.DoubleHelper.operatorStar(1000.0, elapsed), iter), tracer.BenchmarkBase.iters);
    }
    public java.lang.Double measureForExercise(int timeMinimum)
    {
      int time = 0;
      int iter = 0;
      dart.core.Stopwatch watch = new dart.core.Stopwatch();
      watch.start();
      int elapsed = 0;
      while (dart._runtime.helpers.IntegerHelper.operatorLess(elapsed, timeMinimum))
      {
        this.exercise();
        elapsed = watch.getElapsedMilliseconds();
        iter = dart._runtime.helpers.IntegerHelper.operatorPlus(iter, 1);
      }
      return dart._runtime.helpers.DoubleHelper.operatorDivide(dart._runtime.helpers.DoubleHelper.operatorDivide(dart._runtime.helpers.DoubleHelper.operatorStar(1000.0, elapsed), iter), tracer.BenchmarkBase.iters);
    }
    public java.lang.Double measure()
    {
      this.setup();
      this.measureForWarumup(100);
      java.lang.Double result = this.measureForExercise(dart._runtime.helpers.IntegerHelper.operatorStar(10, 1000));
      this.teardown();
      return result;
    }
    public void report()
    {
      java.lang.Double score = this.measure();
      dart.core.__TopLevel.print((((("" + this.getName().toString()) + "(RunTime): ") + score.toString()) + " us."));
    }
    public java.lang.String getName()
    {
      return this.name;
    }
    public static int getIters()
    {
      return tracer.BenchmarkBase.iters;
    }
    public static int setIters(int value)
    {
      tracer.BenchmarkBase.iters = value;
      return value;
    }
}