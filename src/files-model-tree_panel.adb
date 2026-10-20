separate (Files.Model)
package body Tree_Panel is

   procedure Clamp_Tree_Panel_Scroll
     (Model : in out Window_Model)
   is
      Count : constant Natural :=
        Natural (Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value).Length);
      Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
   begin
      Model.Tree_Panel_Scroll := Natural'Min (Model.Tree_Panel_Scroll, Maximum);
   end Clamp_Tree_Panel_Scroll;

   procedure Reconcile_Tree_Pick_Target
     (Model          : in out Window_Model;
      Fallback_Index : Positive)
   is
      Rows : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
        Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value);
      Target : constant String := To_String (Model.Tree_Pick_Target_Value);
      Fallback : constant String :=
        Files.Folder_Tree.Node_Path (Model.Folder_Tree_Value, Fallback_Index);
      Target_Visible   : Boolean := False;
      Fallback_Visible : Boolean := False;
   begin
      if Model.Tree_Pick_Mode_Value = Pick_None or else Target = "" then
         return;
      end if;

      for Row of Rows loop
         Target_Visible :=
           Target_Visible or else To_String (Row.Path) = Target;
         Fallback_Visible :=
           Fallback_Visible or else To_String (Row.Path) = Fallback;
      end loop;

      if Target_Visible then
         return;
      elsif Fallback_Visible then
         Model.Tree_Pick_Target_Value := To_Unbounded_String (Fallback);
      elsif not Rows.Is_Empty then
         Model.Tree_Pick_Target_Value := Rows.First_Element.Path;
      else
         Model.Tree_Pick_Target_Value := Null_Unbounded_String;
      end if;
   end Reconcile_Tree_Pick_Target;

   procedure Toggle_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := not Model.Tree_Panel_Open;
      if not Model.Tree_Panel_Open then
         Model.Tree_Panel_Scroll := 0;
      end if;
   end Toggle_Tree_Panel;

   procedure Open_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := True;
   end Open_Tree_Panel;

   procedure Close_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := False;
      --  Closing the sidebar also abandons any in-flight destination picker so
      --  a later reopen starts clean.
      Model.Tree_Pick_Mode_Value := Pick_None;
      Model.Tree_Pick_Sources_Value.Clear;
      Model.Tree_Pick_Target_Value := Null_Unbounded_String;
      Model.Tree_Panel_Scroll := 0;
   end Close_Tree_Panel;

   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Pick_Mode_Value := Mode;
      if Mode /= Pick_None then
         Claim_Overlay_Input (Model);
      end if;
      Model.Tree_Pick_Sources_Value := Sources;
      Model.Tree_Pick_Target_Value := To_Unbounded_String (Initial_Target);
   end Begin_Tree_Pick;

   procedure Set_Tree_Pick_Target
     (Model  : in out Window_Model;
      Target : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Pick_Target_Value := To_Unbounded_String (Target);
   end Set_Tree_Pick_Target;

   procedure Clear_Tree_Pick
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Pick_Mode_Value := Pick_None;
      Model.Tree_Pick_Sources_Value.Clear;
      Model.Tree_Pick_Target_Value := Null_Unbounded_String;
   end Clear_Tree_Pick;

   function Tree_Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode is
   begin
      return Model.Tree_Pick_Mode_Value;
   end Tree_Pick_Mode_Of;

   function Tree_Pick_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Tree_Pick_Mode_Value /= Pick_None;
   end Tree_Pick_Is_Active;

   function Tree_Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Tree_Pick_Sources_Value;
   end Tree_Pick_Sources;

   function Tree_Pick_Target
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Tree_Pick_Target_Value);
   end Tree_Pick_Target;

   function Tree_Panel_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Tree_Panel_Open;
   end Tree_Panel_Is_Open;

   function Tree_Panel_Scroll_Rows
     (Model : Window_Model)
      return Natural
   is
      Count : constant Natural :=
        Natural (Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value).Length);
   begin
      return
        (if Count = 0 then 0
         else Natural'Min (Model.Tree_Panel_Scroll, Count - 1));
   end Tree_Panel_Scroll_Rows;

   procedure Set_Tree_Panel_Scroll_Rows
     (Model : in out Window_Model;
      Rows  : Natural)
   is
      Count : constant Natural :=
        Natural (Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value).Length);
      Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
      Value   : constant Natural := Natural'Min (Rows, Maximum);
   begin
      if not Model.Tree_Panel_Open or else Model.Tree_Panel_Scroll = Value then
         return;
      end if;

      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Scroll := Value;
   end Set_Tree_Panel_Scroll_Rows;

   procedure Scroll_Tree_Panel
     (Model : in out Window_Model;
      Rows  : Integer)
   is
      Current : constant Natural := Tree_Panel_Scroll_Rows (Model);
      Count   : constant Natural :=
        Natural (Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value).Length);
      Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
      Step    : Natural;
      Wanted  : Natural;
   begin
      if not Model.Tree_Panel_Open or else Rows = 0 then
         return;
      end if;

      if Rows < 0 then
         Step := (if Rows = Integer'First then Natural'Last else Natural (-Rows));
         Wanted := (if Step >= Current then 0 else Current - Step);
      else
         Step := Natural (Rows);
         Wanted := Natural'Min (Maximum, Saturating_Add (Current, Step));
      end if;

      --  Compare the stored value as well as its clamped public projection. A
      --  collapse can temporarily reduce the row count; the next scroll should
      --  normalize that stale offset rather than letting it resurface later.
      if Model.Tree_Panel_Scroll /= Wanted then
         Model.Revision_Value := Model.Revision_Value + 1;
         Model.Tree_Panel_Scroll := Wanted;
      end if;
   end Scroll_Tree_Panel;

   procedure Ensure_Tree_Row_Visible
     (Model       : in out Window_Model;
      Visible_Row : Positive;
      Page_Rows   : Natural)
   is
      Count : constant Natural :=
        Natural (Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value).Length);
      Maximum : constant Natural :=
        (if Count > Page_Rows then Count - Page_Rows else 0);
      Current : constant Natural :=
        Natural'Min (Tree_Panel_Scroll_Rows (Model), Maximum);
      Target  : constant Natural := Visible_Row - 1;
      Wanted  : Natural := Current;
   begin
      if not Model.Tree_Panel_Open
        or else Page_Rows = 0
        or else Count = 0
        or else Visible_Row > Count
      then
         return;
      end if;

      if Target < Current then
         Wanted := Target;
      elsif Target - Current >= Page_Rows then
         Wanted := Target - Page_Rows + 1;
      end if;
      Wanted := Natural'Min (Wanted, Maximum);

      if Model.Tree_Panel_Scroll /= Wanted then
         Model.Revision_Value := Model.Revision_Value + 1;
         Model.Tree_Panel_Scroll := Wanted;
      end if;
   end Ensure_Tree_Row_Visible;

   function Tree_Is_Seeded
     (Model : Window_Model)
      return Boolean is
   begin
      return Files.Folder_Tree.Is_Seeded (Model.Folder_Tree_Value);
   end Tree_Is_Seeded;

   procedure Seed_Tree
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Scroll := 0;
      Files.Folder_Tree.Seed (Model.Folder_Tree_Value, Roots);
   end Seed_Tree;

   function Tree_Node_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Files.Folder_Tree.Node_Count (Model.Folder_Tree_Value);
   end Tree_Node_Count;

   function Tree_Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
   begin
      return Files.Folder_Tree.Node_Path (Model.Folder_Tree_Value, Index);
   end Tree_Node_Path;

   function Tree_Node_Is_Loaded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      return Files.Folder_Tree.Node_Is_Loaded (Model.Folder_Tree_Value, Index);
   end Tree_Node_Is_Loaded;

   function Tree_Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
   begin
      return Files.Folder_Tree.Node_Is_Expanded (Model.Folder_Tree_Value, Index);
   end Tree_Node_Is_Expanded;

   procedure Tree_Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Set_Children (Model.Folder_Tree_Value, Index, Children);
      Clamp_Tree_Panel_Scroll (Model);
      Reconcile_Tree_Pick_Target (Model, Index);
   end Tree_Set_Children;

   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Set_Expanded (Model.Folder_Tree_Value, Index, Expanded);
      Clamp_Tree_Panel_Scroll (Model);
      Reconcile_Tree_Pick_Target (Model, Index);
   end Tree_Set_Expanded;

   procedure Tree_Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Toggle_Expanded (Model.Folder_Tree_Value, Index);
      Clamp_Tree_Panel_Scroll (Model);
      Reconcile_Tree_Pick_Target (Model, Index);
   end Tree_Toggle_Expanded;

   function Tree_Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector is
   begin
      return Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value);
   end Tree_Visible_Rows;

end Tree_Panel;
