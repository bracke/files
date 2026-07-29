separate (Files.Model)
package body Undo_Redo is

   --  Cap the undo history so a session doing thousands of operations does not
   --  grow it without bound: each entry retains the full source and destination
   --  path lists (and permission/ownership images), so an unbounded stack pins
   --  that data for the life of the window. Past the cap the oldest entry --
   --  least likely to ever be undone -- is dropped; LIFO undo only touches the
   --  newest, so the reachable history is unaffected.
   Max_Undo_Depth : constant := 200;

   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Kind = Undo_None or else From.Is_Empty then
         return;
      end if;

      Model.Undo_Stack.Append
        (Undo_Entry'
           (Kind          => Kind,
            From          => From,
            To            => To,
            Forward       => Forward,
            Create_Kind   => Create_Kind,
            Redoable      => Redoable,
            Restore_Trash => Restore_Trash));
      while Natural (Model.Undo_Stack.Length) > Max_Undo_Depth loop
         Model.Undo_Stack.Delete_First;
      end loop;
      Model.Redo_Stack.Clear;
   end Record_Undo;

   procedure Clear_Undo
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Undo_Stack.Clear;
      Model.Redo_Stack.Clear;
   end Clear_Undo;

   function Undo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Undo_Stack.Is_Empty;
   end Undo_Available;

   function Redo_Available
     (Model : Window_Model)
      return Boolean is
   begin
      return not Model.Redo_Stack.Is_Empty;
   end Redo_Available;

   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Undo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Undo_Stack.Last_Element;
      Model.Undo_Stack.Delete_Last;
      Found := True;
   end Take_Undo;

   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Model.Redo_Stack.Is_Empty then
         Action := (others => <>);
         Found := False;
         return;
      end if;

      Action := Model.Redo_Stack.Last_Element;
      Model.Redo_Stack.Delete_Last;
      Found := True;
   end Take_Redo;

   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Redo_Stack.Append (Action);
   end Push_Redo;

   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Undo_Stack.Append (Action);
   end Push_Undo;

   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Undo_None;
      end if;

      return Model.Undo_Stack.Last_Element.Kind;
   end Undo_Kind_Of;

   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.Undo_Stack.Last_Element.From;
   end Undo_From_Paths;

   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.Undo_Stack.Last_Element.To;
   end Undo_To_Paths;

end Undo_Redo;
