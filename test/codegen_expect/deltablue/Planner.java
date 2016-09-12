package deltablue;

public class Planner extends dart._runtime.base.DartObject implements deltablue.Planner_interface
{
    public static dart._runtime.types.simple.InterfaceTypeInfo dart2java$typeInfo = new dart._runtime.types.simple.InterfaceTypeInfo(deltablue.Planner.class, deltablue.Planner_interface.class);
    private static dart._runtime.types.simple.InterfaceTypeExpr dart2java$typeExpr_Plan = new dart._runtime.types.simple.InterfaceTypeExpr(deltablue.Plan.dart2java$typeInfo);
    private static dart._runtime.types.simple.InterfaceTypeExpr dart2java$typeExpr_Object = new dart._runtime.types.simple.InterfaceTypeExpr(dart._runtime.helpers.ObjectHelper.dart2java$typeInfo);
    static {
      deltablue.Planner.dart2java$typeInfo.superclass = dart2java$typeExpr_Object;
    }
    public int currentMark;
  
    public Planner(dart._runtime.types.simple.Type type)
    {
      super(((dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker) null), type);
      this._constructor();
    }
    public Planner(dart._runtime.helpers.ConstructorHelper.EmptyConstructorMarker arg, dart._runtime.types.simple.Type type)
    {
      super(arg, type);
    }
  
    protected void _constructor()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      this.currentMark = 0;
      super._constructor();
    }
    public void incrementalAdd(deltablue.Constraint_interface c)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      int mark = this.newMark();
      for (deltablue.Constraint_interface overridden = c.satisfy(mark); (!dart._runtime.helpers.ObjectHelper.operatorEqual(overridden, null)); overridden = overridden.satisfy(mark))
      {
        
      }
    }
    public void incrementalRemove(deltablue.Constraint_interface c)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      deltablue.Variable_interface out = c.output();
      c.markUnsatisfied();
      c.removeFromGraph();
      dart.core.List_interface<deltablue.Constraint_interface> unsatisfied = ((dart.core.List_interface) this.removePropagateFrom(out));
      deltablue.Strength_interface strength = deltablue.__TopLevel.REQUIRED;
      do
      {
        for (int i = 0; (i < unsatisfied.getLength()); i = (i + 1))
        {
          deltablue.Constraint_interface u = unsatisfied.operatorAt(i);
          if (dart._runtime.helpers.ObjectHelper.operatorEqual(u.getStrength(), strength))
          {
            this.incrementalAdd(u);
          }
        }
        strength = strength.nextWeaker();
      }
      while ((!dart._runtime.helpers.ObjectHelper.operatorEqual(strength, deltablue.__TopLevel.WEAKEST)));
    }
    public int newMark()
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      deltablue.Planner_interface __tempVar_0;
      return dart._runtime.helpers.LetExpressionHelper.comma(__tempVar_0 = this, __tempVar_0.setCurrentMark((__tempVar_0.getCurrentMark() + 1)));
    }
    public deltablue.Plan_interface makePlan(dart.core.List_interface<deltablue.Constraint_interface> sources)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      int mark = this.newMark();
      deltablue.Plan_interface plan = new deltablue.Plan(dart2java$localTypeEnv.evaluate(dart2java$typeExpr_Plan));
      dart.core.List_interface<deltablue.Constraint_interface> todo = ((dart.core.List_interface) sources);
      while ((todo.getLength() > 0))
      {
        deltablue.Constraint_interface c = todo.removeLast();
        if (((!(c.output().getMark() == mark)) && c.inputsKnown(mark)))
        {
          plan.addConstraint(c);
          c.output().setMark(mark);
          this.addConstraintsConsumingTo(c.output(), ((dart.core.List_interface) todo));
        }
      }
      return plan;
    }
    public deltablue.Plan_interface extractPlanFromConstraints(dart.core.List_interface<deltablue.Constraint_interface> constraints)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      dart.core.List_interface<deltablue.Constraint_interface> sources = ((dart.core.List_interface) dart._runtime.base.DartList.Generic._fromArguments(deltablue.Constraint_interface.class));
      for (int i = 0; (i < constraints.getLength()); i = (i + 1))
      {
        deltablue.Constraint_interface c = constraints.operatorAt(i);
        if ((c.isInput() && c.isSatisfied()))
        {
          sources.add(c);
        }
      }
      return this.makePlan(((dart.core.List_interface) sources));
    }
    public boolean addPropagate(deltablue.Constraint_interface c, int mark)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      dart.core.List_interface<deltablue.Constraint_interface> todo = ((dart.core.List_interface) dart._runtime.base.DartList.Generic._fromArguments(deltablue.Constraint_interface.class, c));
      while ((todo.getLength() > 0))
      {
        deltablue.Constraint_interface d = todo.removeLast();
        if ((d.output().getMark() == mark))
        {
          this.incrementalRemove(c);
          return false;
        }
        d.recalculate();
        this.addConstraintsConsumingTo(d.output(), ((dart.core.List_interface) todo));
      }
      return true;
    }
    public dart.core.List_interface<deltablue.Constraint_interface> removePropagateFrom(deltablue.Variable_interface out)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      out.setDeterminedBy(null);
      out.setWalkStrength(deltablue.__TopLevel.WEAKEST);
      out.setStay(true);
      dart.core.List_interface<deltablue.Constraint_interface> unsatisfied = ((dart.core.List_interface) dart._runtime.base.DartList.Generic._fromArguments(deltablue.Constraint_interface.class));
      dart.core.List_interface<deltablue.Variable_interface> todo = ((dart.core.List_interface) dart._runtime.base.DartList.Generic._fromArguments(deltablue.Variable_interface.class, out));
      while ((todo.getLength() > 0))
      {
        deltablue.Variable_interface v = todo.removeLast();
        for (int i = 0; (i < v.getConstraints().getLength()); i = (i + 1))
        {
          deltablue.Constraint_interface c = v.getConstraints().operatorAt(i);
          if ((!c.isSatisfied()))
          {
            unsatisfied.add(c);
          }
        }
        deltablue.Constraint_interface determining = v.getDeterminedBy();
        for (int i = 0; (i < v.getConstraints().getLength()); i = (i + 1))
        {
          deltablue.Constraint_interface next = v.getConstraints().operatorAt(i);
          if (((!dart._runtime.helpers.ObjectHelper.operatorEqual(next, determining)) && next.isSatisfied()))
          {
            next.recalculate();
            todo.add(next.output());
          }
        }
      }
      return ((dart.core.List_interface) unsatisfied);
    }
    public void addConstraintsConsumingTo(deltablue.Variable_interface v, dart.core.List_interface<deltablue.Constraint_interface> coll)
    {
      final dart._runtime.types.simple.TypeEnvironment dart2java$localTypeEnv = this.dart2java$type.env;
      deltablue.Constraint_interface determining = v.getDeterminedBy();
      for (int i = 0; (i < v.getConstraints().getLength()); i = (i + 1))
      {
        deltablue.Constraint_interface c = v.getConstraints().operatorAt(i);
        if (((!dart._runtime.helpers.ObjectHelper.operatorEqual(c, determining)) && c.isSatisfied()))
        {
          coll.add(c);
        }
      }
    }
    public int getCurrentMark()
    {
      return this.currentMark;
    }
    public int setCurrentMark(int value)
    {
      this.currentMark = value;
      return value;
    }
}
