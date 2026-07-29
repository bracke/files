with Files.Model.Support;
with Files.Type_Ahead;

separate (Files.Model)
package body Filter is
   use Files.Model.Support;
   use type Files.Types.Search_Scope;
   use Ada.Strings.Unbounded;

   procedure Set_Filter
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Filter_Value := To_Unbounded_String (Text);
      Model.Filter_Cursor := Text'Length;
      Model.Main_View_Scroll := 0;
      Reconcile_Selection (Model);
   end Set_Filter;

   function Filter_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Filter_Value);
   end Filter_Text;

   procedure Clear_Filter
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Set_Filter (Model, "");
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
   end Clear_Filter;

   function Search_Scope_Of
     (Model : Window_Model)
      return Files.Types.Search_Scope is
   begin
      return Model.Search_Scope_Value;
   end Search_Scope_Of;

   procedure Set_Search_Scope
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Search_Scope_Value := Scope;
   end Set_Search_Scope;

   function Search_Results_Are_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Search_Results_Active;
   end Search_Results_Are_Active;

   procedure Note_Search_Results
     (Model : in out Window_Model;
      Scope : Files.Types.Search_Scope) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Search_Scope_Value := Scope;
      Model.Search_Results_Active := Scope /= Files.Types.Filter_Here;
   end Note_Search_Results;

   procedure Clear_Search_Results
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Search_Scope_Value := Files.Types.Filter_Here;
      Model.Search_Results_Active := False;
   end Clear_Search_Results;

   procedure Reset_Type_Ahead
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Type_Ahead_Buffer_Value := Null_Unbounded_String;
   end Reset_Type_Ahead;

   function Type_Ahead_Buffer
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Type_Ahead_Buffer_Value);
   end Type_Ahead_Buffer;

   procedure Type_Ahead_Input
     (Model   : in out Window_Model;
      Text    : String;
      Matched : out Boolean)
   is
      Combined : constant String := To_String (Model.Type_Ahead_Buffer_Value) & Text;
      Current  : constant Natural := Selected_Index (Model);
      Visible  : Files.File_System.Item_Vectors.Vector;
      Count    : constant Natural := Visible_Count (Model);
      Prefix   : Unbounded_String;
      Start    : Natural;
      Target   : Natural;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Matched := False;

      if not Is_Printable_Run (Text) then
         return;
      end if;

      --  Snapshot the visible projection in display order so the pure matcher's
      --  returned index maps straight back to a visible index. Temporary
      --  create-file items are never type-ahead targets.
      for Visible_Index in 1 .. Count loop
         if Visible_To_Item_Index (Model, Visible_Index) /= 0 then
            Visible.Append (Visible_Item (Model, Visible_Index));
         else
            Visible.Append (Files.File_System.Directory_Item'(others => <>));
         end if;
      end loop;

      --  Repeatedly typing one letter cycles through the items beginning with
      --  it: collapse the prefix to that single codepoint and scan from just
      --  after the current selection. Any other run refines in place, scanning
      --  from the current selection so an already-matching item is kept.
      if Is_Repeated_Single_Codepoint (Combined) then
         Prefix := To_Unbounded_String (First_Codepoint (Combined));
         Start := Current + 1;
      else
         Prefix := To_Unbounded_String (Combined);
         Start := Current;
      end if;

      Model.Type_Ahead_Buffer_Value := Prefix;

      Target := Files.Type_Ahead.Type_Ahead_Target (Visible, To_String (Prefix), Start);
      if Target > 0 then
         Select_Visible_Internal (Model, Target);
         Matched := True;
      end if;
   end Type_Ahead_Input;

   procedure Focus_Filter_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Filter_Input;
      Model.Filter_Cursor := Length (Model.Filter_Value);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Filter_Input;

end Filter;
