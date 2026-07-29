with Files.Model.Support;

separate (Files.Model)
package body Path_Input is
   use Files.Model.Support;
   use type Files.File_System.Path_Status;
   use Ada.Strings.Unbounded;

   procedure Focus_Path_Input
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Path_Input;
      Model.Path_Input_Value := Model.Current_Path_Value;
      Model.Path_Input_Cursor := Length (Model.Path_Input_Value);
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Path_Input;

   procedure Set_Path_Input_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Path_Input_Value := To_Unbounded_String (Text);
      Model.Path_Input_Cursor := Text'Length;
      Model.Path_Input_Valid := True;
      Model.Path_Input_Error := Null_Unbounded_String;
   end Set_Path_Input_Text;

   function Path_Input_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Path_Input_Value);
   end Path_Input_Text;

   procedure Commit_Path_Input
     (Model  : in out Window_Model;
      Result : Files.File_System.Path_Result;
      Items  : Files.File_System.Item_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Result.Status = Files.File_System.Path_Valid then
         Navigate_To (Model, To_String (Result.Directory_Path), Items);
         Model.Focus_Value := Files.Types.Focus_None;
      else
         Model.Path_Input_Valid := False;
         Model.Path_Input_Error := Result.Error_Key;
      end if;
   end Commit_Path_Input;

   function Path_Input_Is_Valid
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Path_Input_Valid;
   end Path_Input_Is_Valid;

   function Path_Input_Error_Key
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Path_Input_Error);
   end Path_Input_Error_Key;

end Path_Input;
