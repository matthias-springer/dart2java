package deltablue;

public abstract class BinaryConstraint extends deltablue.Constraint implements deltablue.BinaryConstraint_interface
{
    public static dart._runtime.types.simple.InterfaceTypeInfo dart2java$typeInfo = new dart._runtime.types.simple.InterfaceTypeInfo(deltablue.BinaryConstraint.class, deltablue.BinaryConstraint_interface.class);
    private static dart._runtime.types.simple.InterfaceTypeExpr dart2java$typeExpr_Constraint = new dart._runtime.types.simple.InterfaceTypeExpr(deltablue.Constraint.dart2java$typeInfo);
    static {
      deltablue.BinaryConstraint.dart2java$typeInfo.superclass = dart2java$typeExpr_Constraint;
    }
    public deltablue.Variable_interface v1;
    public deltablue.Variable_interface v2;
    public int direction;
  
    public BinaryConstraint(dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker arg, dart._runtime.types.simple.Type type)
    {
      super(arg, type);
    }
  
    public void chooseMethod(int mark)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      if ((this.getV1().getMark() == mark))
      {
        this.setDirection(((((!(this.getV2().getMark() == mark)) && deltablue.Strength.stronger(this.getStrength(), this.getV2().getWalkStrength()))) ? (deltablue.__TopLevel.FORWARD) : (deltablue.__TopLevel.NONE)));
      }
      if ((this.getV2().getMark() == mark))
      {
        this.setDirection(((((!(this.getV1().getMark() == mark)) && deltablue.Strength.stronger(this.getStrength(), this.getV1().getWalkStrength()))) ? (deltablue.__TopLevel.BACKWARD) : (deltablue.__TopLevel.NONE)));
      }
      if (deltablue.Strength.weaker(this.getV1().getWalkStrength(), this.getV2().getWalkStrength()))
      {
        this.setDirection(((deltablue.Strength.stronger(this.getStrength(), this.getV1().getWalkStrength())) ? (deltablue.__TopLevel.BACKWARD) : (deltablue.__TopLevel.NONE)));
      }
      else
      {
        this.setDirection(((deltablue.Strength.stronger(this.getStrength(), this.getV2().getWalkStrength())) ? (deltablue.__TopLevel.FORWARD) : (deltablue.__TopLevel.BACKWARD)));
      }
    }
    public void addToGraph()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.getV1().addConstraint(this);
      this.getV2().addConstraint(this);
      this.setDirection(deltablue.__TopLevel.NONE);
    }
    public boolean isSatisfied()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      return (!(this.getDirection() == deltablue.__TopLevel.NONE));
    }
    public void markInputs(int mark)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.input().setMark(mark);
    }
    public deltablue.Variable_interface input()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      return (((this.getDirection() == deltablue.__TopLevel.FORWARD)) ? (this.getV1()) : (this.getV2()));
    }
    public deltablue.Variable_interface output()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      return (((this.getDirection() == deltablue.__TopLevel.FORWARD)) ? (this.getV2()) : (this.getV1()));
    }
    public void recalculate()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      deltablue.Variable_interface ihn = this.input();
      deltablue.Variable_interface out = this.output();
      out.setWalkStrength(deltablue.Strength.weakest(this.getStrength(), ihn.getWalkStrength()));
      out.setStay(ihn.getStay());
      if (out.getStay())
      {
        this.execute();
      }
    }
    public void markUnsatisfied()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.setDirection(deltablue.__TopLevel.NONE);
    }
    public boolean inputsKnown(int mark)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      deltablue.Variable_interface i = this.input();
      return (((i.getMark() == mark) || i.getStay()) || dart._runtime.helpers.ObjectHelper.operatorEqual(i.getDeterminedBy(), null));
    }
    public void removeFromGraph()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      if ((!dart._runtime.helpers.ObjectHelper.operatorEqual(this.getV1(), null)))
      {
        this.getV1().removeConstraint(this);
      }
      if ((!dart._runtime.helpers.ObjectHelper.operatorEqual(this.getV2(), null)))
      {
        this.getV2().removeConstraint(this);
      }
      this.setDirection(deltablue.__TopLevel.NONE);
    }
    public void _constructor(deltablue.Variable_interface v1, deltablue.Variable_interface v2, deltablue.Strength_interface strength)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.direction = deltablue.__TopLevel.NONE;
      this.v1 = v1;
      this.v2 = v2;
      super._constructor(strength);
      this.addConstraint();
    }
    public deltablue.Variable_interface getV1()
    {
      return this.v1;
    }
    public deltablue.Variable_interface getV2()
    {
      return this.v2;
    }
    public int getDirection()
    {
      return this.direction;
    }
    public deltablue.Variable_interface setV1(deltablue.Variable_interface value)
    {
      this.v1 = value;
      return value;
    }
    public deltablue.Variable_interface setV2(deltablue.Variable_interface value)
    {
      this.v2 = value;
      return value;
    }
    public int setDirection(int value)
    {
      this.direction = value;
      return value;
    }
}
