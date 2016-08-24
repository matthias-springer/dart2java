package tracer;

public class Camera extends dart._runtime.base.DartObject
{
    public static dart._runtime.types.simple.InterfaceTypeInfo dart2java$typeInfo = new dart._runtime.types.simple.InterfaceTypeInfo("file:///usr/local/google/home/springerm/ddc-java/gen/codegen_tests/tracer.dart", "Camera");
    static {
      tracer.Camera.dart2java$typeInfo.superclass = new dart._runtime.types.simple.InterfaceTypeExpr(dart._runtime.helpers.ObjectHelper.dart2java$typeInfo);
    }
    public java.lang.Object position;
    public java.lang.Object lookAt;
    public java.lang.Object up;
    public java.lang.Object equator;
    public java.lang.Object screen;
  
    public Camera(java.lang.Object position, java.lang.Object lookAt, java.lang.Object up)
    {
      super((dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker) null);
      this._constructor(position, lookAt, up);
    }
    public Camera(dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker arg)
    {
      super(arg);
    }
  
    protected void _constructor(java.lang.Object position, java.lang.Object lookAt, java.lang.Object up)
    {
      this.position = position;
      this.lookAt = lookAt;
      this.up = up;
      super._constructor();
      this.setEquator(dart._runtime.helpers.DynamicHelper.invoke("cross", dart._runtime.helpers.DynamicHelper.invoke("normalize", this.getLookAt()), this.getUp()));
      this.setScreen(dart._runtime.helpers.DynamicHelper.invoke("operatorPlus", this.getPosition(), this.getLookAt()));
    }
    public tracer.Ray getRay(java.lang.Double vx, java.lang.Double vy)
    {
      java.lang.Object pos = dart._runtime.helpers.DynamicHelper.invoke("operatorMinus", this.getScreen(), dart._runtime.helpers.DynamicHelper.invoke("operatorMinus", dart._runtime.helpers.DynamicHelper.invoke("multiplyScalar", this.getEquator(), vx), dart._runtime.helpers.DynamicHelper.invoke("multiplyScalar", this.getUp(), vy)));
      pos = dart._runtime.helpers.DynamicHelper.invoke("negateY", pos);
      java.lang.Object dir = dart._runtime.helpers.DynamicHelper.invoke("operatorMinus", pos, this.getPosition());
      tracer.Ray ray = new tracer.Ray(pos, dart._runtime.helpers.DynamicHelper.invoke("normalize", dir));
      return ray;
    }
    public java.lang.String toString()
    {
      return "Camera []";
    }
    public java.lang.Object getPosition()
    {
      return this.position;
    }
    public java.lang.Object getLookAt()
    {
      return this.lookAt;
    }
    public java.lang.Object getUp()
    {
      return this.up;
    }
    public java.lang.Object getEquator()
    {
      return this.equator;
    }
    public java.lang.Object getScreen()
    {
      return this.screen;
    }
    public java.lang.Object setEquator(java.lang.Object value)
    {
      this.equator = value;
      return value;
    }
    public java.lang.Object setScreen(java.lang.Object value)
    {
      this.screen = value;
      return value;
    }
}