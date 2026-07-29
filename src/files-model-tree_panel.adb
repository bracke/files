separate (Files.Model)
package body Tree_Panel is
   use Ada.Strings.Unbounded;

   procedure Toggle_Tree_Panel
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Panel_Open := not Model.Tree_Panel_Open;
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
   end Close_Tree_Panel;

   procedure Begin_Tree_Pick
     (Model          : in out Window_Model;
      Mode           : Tree_Pick_Mode;
      Sources        : Files.Types.String_Vectors.Vector;
      Initial_Target : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Tree_Pick_Mode_Value := Mode;
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
   end Tree_Set_Children;

   procedure Tree_Set_Expanded
     (Model    : in out Window_Model;
      Index    : Positive;
      Expanded : Boolean) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Set_Expanded (Model.Folder_Tree_Value, Index, Expanded);
   end Tree_Set_Expanded;

   procedure Tree_Toggle_Expanded
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Files.Folder_Tree.Toggle_Expanded (Model.Folder_Tree_Value, Index);
   end Tree_Toggle_Expanded;

   function Tree_Visible_Rows
     (Model : Window_Model)
      return Files.Folder_Tree.Visible_Row_Vectors.Vector is
   begin
      return Files.Folder_Tree.Visible_Rows (Model.Folder_Tree_Value);
   end Tree_Visible_Rows;

end Tree_Panel;
