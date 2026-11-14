with Guikit.Layout;
with Files.Model.Support;

package body Files.Model.Tree_Panel is

   use Ada.Strings.Unbounded;
   use type Files.Types.Focus_Target;
   use Files.Model.Support;

   procedure Clamp_Tree_Panel_Scroll
     (Model : in out Window_Model)
   is
      Count : constant Natural :=
        Files.Folder_Tree.Visible_Row_Count (Model.Tree_Panel.Tree);
      Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
   begin
      Model.Tree_Panel.Scroll := Natural'Min (Model.Tree_Panel.Scroll, Maximum);
   end Clamp_Tree_Panel_Scroll;

   procedure Reconcile_Tree_Pick_Target
     (Model          : in out Window_Model;
      Fallback_Index : Positive)
   is
      Rows : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
        Files.Folder_Tree.Visible_Rows (Model.Tree_Panel.Tree);
      Target : constant String := To_String (Model.Tree_Pick.Target);
      Fallback : constant String :=
        Files.Folder_Tree.Node_Path (Model.Tree_Panel.Tree, Fallback_Index);
      Target_Visible   : Boolean := False;
      Fallback_Visible : Boolean := False;
   begin
      if Model.Tree_Pick.Mode = Pick_None or else Target = "" then
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
         Model.Tree_Pick.Target := To_Unbounded_String (Fallback);
      elsif not Rows.Is_Empty then
         Model.Tree_Pick.Target := Rows.First_Element.Path;
      else
         Model.Tree_Pick.Target := Null_Unbounded_String;
      end if;
   end Reconcile_Tree_Pick_Target;

   procedure Open
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Tree_Panel.Open := True;
   end Open;

   procedure Close
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Tree_Panel.Open := False;
      --  Closing the sidebar also abandons any in-flight destination picker so
      --  a later reopen starts clean. Whether the picker opened the sidebar is
      --  kept for End_Pick, which reads it after closing.
      Model.Tree_Pick := (Opened_Panel => Model.Tree_Pick.Opened_Panel, others => <>);
      Model.Tree_Panel.Scroll := 0;
      Model.Tree_Panel.Keyboard := False;
   end Close;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Tree_Panel.Open);

   procedure Scroll
     (Model : in out Window_Model;
      Rows  : Integer)
   is
      Current : constant Natural := Scroll_Rows (Model);
      Count   : constant Natural :=
        Files.Folder_Tree.Visible_Row_Count (Model.Tree_Panel.Tree);
      Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
      Step    : Natural;
      Wanted  : Natural;
   begin
      if not Model.Tree_Panel.Open or else Rows = 0 then
         return;
      end if;

      if Rows < 0 then
         Step := (if Rows = Integer'First then Natural'Last else Natural (-Rows));
         Wanted := (if Step >= Current then 0 else Current - Step);
      else
         Step := Natural (Rows);
         Wanted := Natural'Min (Maximum, Guikit.Layout.Saturating_Add (Current, Step));
      end if;

      --  Compare the stored value as well as its clamped public projection. A
      --  collapse can temporarily reduce the row count; the next scroll should
      --  normalize that stale offset rather than letting it resurface later.
      if Model.Tree_Panel.Scroll /= Wanted then
         Model.Scroll_Revision_Value := Model.Scroll_Revision_Value + 1;
         Model.Tree_Panel.Scroll := Wanted;
      end if;
   end Scroll;

   function Scroll_Rows
     (Model : Window_Model)
      return Natural
   is
      Count : constant Natural :=
        Files.Folder_Tree.Visible_Row_Count (Model.Tree_Panel.Tree);
   begin
      return
        (if Count = 0 then 0
         else Natural'Min (Model.Tree_Panel.Scroll, Count - 1));
   end Scroll_Rows;

   procedure Set_Scroll_Rows
     (Model : in out Window_Model;
      Rows  : Natural)
   is
      Count : constant Natural :=
        Files.Folder_Tree.Visible_Row_Count (Model.Tree_Panel.Tree);
      Maximum : constant Natural := (if Count = 0 then 0 else Count - 1);
      Value   : constant Natural := Natural'Min (Rows, Maximum);
   begin
      if not Model.Tree_Panel.Open or else Model.Tree_Panel.Scroll = Value then
         return;
      end if;

      Model.Scroll_Revision_Value := Model.Scroll_Revision_Value + 1;
      Model.Tree_Panel.Scroll := Value;
   end Set_Scroll_Rows;

   procedure Ensure_Row_Visible
     (Model       : in out Window_Model;
      Visible_Row : Positive;
      Page_Rows   : Natural)
   is
      Count : constant Natural :=
        Files.Folder_Tree.Visible_Row_Count (Model.Tree_Panel.Tree);
      Maximum : constant Natural :=
        (if Count > Page_Rows then Count - Page_Rows else 0);
      Current : constant Natural :=
        Natural'Min (Scroll_Rows (Model), Maximum);
      Target  : constant Natural := Visible_Row - 1;
      Wanted  : Natural := Current;
   begin
      if not Model.Tree_Panel.Open
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

      if Model.Tree_Panel.Scroll /= Wanted then
         Touch (Model);
         Model.Tree_Panel.Scroll := Wanted;
      end if;
   end Ensure_Row_Visible;

   function Is_Seeded
     (Model : Window_Model)
      return Boolean is
     (Files.Folder_Tree.Is_Seeded (Model.Tree_Panel.Tree));

   function Roots_Match
     (Model : Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector)
      return Boolean is (Files.Folder_Tree.Same_Roots (Model.Tree_Panel.Tree, Roots));

   procedure Seed
     (Model : in out Window_Model;
      Roots : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Touch (Model);
      Model.Tree_Panel.Scroll := 0;
      Files.Folder_Tree.Seed (Model.Tree_Panel.Tree, Roots);
   end Seed;

   function Node_Count
     (Model : Window_Model)
      return Natural is
     (Files.Folder_Tree.Node_Count (Model.Tree_Panel.Tree));

   function Node_Path
     (Model : Window_Model;
      Index : Positive)
      return String is
     (Files.Folder_Tree.Node_Path (Model.Tree_Panel.Tree, Index));

   function Node_Is_Expanded
     (Model : Window_Model;
      Index : Positive)
      return Boolean is
     (Files.Folder_Tree.Node_Is_Expanded (Model.Tree_Panel.Tree, Index));

   procedure Set_Children
     (Model    : in out Window_Model;
      Index    : Positive;
      Children : Files.Folder_Tree.Entry_Seed_Vectors.Vector) is
   begin
      Touch (Model);
      Files.Folder_Tree.Replace_Children (Model.Tree_Panel.Tree, Index, Children);
      Clamp_Tree_Panel_Scroll (Model);
      Reconcile_Tree_Pick_Target (Model, Index);
   end Set_Children;

   procedure Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean) is
   begin
      Touch (Model);
      Files.Folder_Tree.Set_Expanded (Model.Tree_Panel.Tree, Index, Expanded);
      Clamp_Tree_Panel_Scroll (Model);
      Reconcile_Tree_Pick_Target (Model, Index);
   end Set_Expanded;

   procedure Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Touch (Model);
      Files.Folder_Tree.Toggle_Expanded (Model.Tree_Panel.Tree, Index);
      Clamp_Tree_Panel_Scroll (Model);
      Reconcile_Tree_Pick_Target (Model, Index);
   end Toggle_Expanded;

   function Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector is
     (Files.Folder_Tree.Visible_Rows (Model.Tree_Panel.Tree));

   procedure Give_Keyboard
     (Model : in out Window_Model)
   is
      Rows : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
        Files.Folder_Tree.Visible_Rows (Model.Tree_Panel.Tree);
   begin
      if not Model.Tree_Panel.Open
        or else Model.Tree_Pick.Mode /= Pick_None
        or else Rows.Is_Empty
      then
         return;
      end if;

      Touch (Model);
      Model.Tree_Panel.Keyboard := True;
      Model.Tree_Panel.Cursor := Rows.First_Element.Path;
      for Row of Rows loop
         if Row.Path = Model.Current_Path_Value then
            Model.Tree_Panel.Cursor := Row.Path;
            exit;
         end if;
      end loop;
   end Give_Keyboard;

   procedure Take_Keyboard
     (Model : in out Window_Model) is
   begin
      if Model.Tree_Panel.Keyboard then
         Touch (Model);
         Model.Tree_Panel.Keyboard := False;
      end if;
   end Take_Keyboard;

   function Has_Keyboard
     (Model : Window_Model)
      return Boolean is
     (Model.Tree_Panel.Keyboard
       and then Model.Tree_Panel.Open
       and then Model.Tree_Pick.Mode = Pick_None
       and then Model.Focus_Value = Files.Types.Focus_None);

   function Cursor
     (Model : Window_Model)
      return String is
     (To_String (Model.Tree_Panel.Cursor));

   procedure Set_Cursor
     (Model : in out Window_Model;
      Path  : String) is
   begin
      Touch (Model);
      Model.Tree_Panel.Cursor := To_Unbounded_String (Path);
   end Set_Cursor;

   procedure Begin_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String) is
   begin
      Touch (Model);
      Model.Tree_Pick :=
        (Mode         => Mode,
         Sources      => Sources,
         Target       => To_Unbounded_String (Initial_Target),
         Opened_Panel => Mode /= Pick_None and then not Model.Tree_Panel.Open);
      if Mode /= Pick_None then
         Claim_Overlay_Input (Model);
         --  The picker has its own highlight; the tree's keyboard turn ends.
         Model.Tree_Panel.Keyboard := False;
      end if;
   end Begin_Pick;

   procedure Set_Pick_Target
     (Model  : in out Window_Model;
      Target : String) is
   begin
      Touch (Model);
      Model.Tree_Pick.Target := To_Unbounded_String (Target);
   end Set_Pick_Target;

   procedure End_Pick (Model : in out Window_Model) is
   begin
      if Model.Tree_Pick.Opened_Panel then
         Close (Model);
      else
         Clear_Tree_Pick (Model);
      end if;
      Model.Tree_Pick.Opened_Panel := False;
   end End_Pick;

   function Pick_Mode_Of
     (Model : Window_Model)
      return Tree_Pick_Mode is
     (Model.Tree_Pick.Mode);

   function Pick_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Tree_Pick.Mode /= Pick_None);

   function Pick_Sources
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
     (Model.Tree_Pick.Sources);

   function Pick_Target
     (Model : Window_Model)
      return String is
     (To_String (Model.Tree_Pick.Target));

end Files.Model.Tree_Panel;
