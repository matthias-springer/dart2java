package deltablue;

public abstract class Constraint extends dart._runtime.base.DartObject
{
    public static dart._runtime.types.simple.InterfaceTypeInfo dart2java$typeInfo = new dart._runtime.types.simple.InterfaceTypeInfo("file:///usr/local/google/home/andrewkrieger/ddc-java/gen/codegen_tests/deltablue.dart", "Constraint");
    static {
      deltablue.Constraint.dart2java$typeInfo.superclass = new dart._runtime.types.simple.InterfaceTypeExpr(dart._runtime.helpers.ObjectHelper.dart2java$typeInfo);
    }
    public deltablue.Strength strength = null;
  
    public Constraint(deltablue.Strength strength)
    {
      super((dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker) null);
      this._constructor(strength);
    }
    public Constraint(dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker arg)
    {
      super(arg);
    }
  
    protected void _constructor(deltablue.Strength strength)
    {
      this.strength = strength;
      super._constructor();
    }
    public abstract java.lang.Boolean isSatisfied();
    public abstract void markUnsatisfied();
    public abstract void addToGraph();
    public abstract void removeFromGraph();
    public abstract void chooseMethod(java.lang.Integer mark);
    public abstract void markInputs(java.lang.Integer mark);
    public abstract java.lang.Boolean inputsKnown(java.lang.Integer mark);
    public abstract deltablue.Variable output();
    public abstract void execute();
    public abstract void recalculate();
    public void addConstraint()
    {
      this.addToGraph();
      deltablue.__TopLevel.planner.incrementalAdd(this);
    }
    public deltablue.Constraint satisfy(java.lang.Integer mark)
    {
      this.chooseMethod(mark);
      if ((!this.isSatisfied()))
      {
        if (dart._runtime.helpers.ObjectHelper.operatorEqual(this.getStrength(), deltablue.__TopLevel.REQUIRED))
        {
          dart.core.__TopLevel.print("Could not satisfy a required constraint!");
        }
        return null;
      }
      this.markInputs(mark);
      deltablue.Variable out = this.output();
      deltablue.Constraint overridden = out.getDeterminedBy();
      if ((!dart._runtime.helpers.ObjectHelper.operatorEqual(overridden, null)))
      {
        overridden.markUnsatisfied();
      }
      out.setDeterminedBy(this);
      if ((!deltablue.__TopLevel.planner.addPropagate(this, mark)))
      {
        dart.core.__TopLevel.print("Cycle encountered");
      }
      out.setMark(mark);
      return overridden;
    }
    public void destroyConstraint()
    {
      if (this.isSatisfied())
      {
        deltablue.__TopLevel.planner.incrementalRemove(this);
      }
      this.removeFromGraph();
    }
    public java.lang.Boolean isInput()
    {
      return false;
    }
    public deltablue.Strength getStrength()
    {
      return this.strength;
    }
}