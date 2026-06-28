package body Files.Accessibility is
   use Ada.Strings.Unbounded;

   function Integration_Profile return Files.Rendering.Accessibility_Integration_Profile is
   begin
      return
        (Render_Node_Tree          => True,
         Native_API_Binding_Status => Files.File_System.Native_API_Binding_Missing,
         Role_Metadata             => True,
         Table_Metadata            => True,
         Pane_Section_Metadata     => True,
         Keyboard_Focus_Metadata   => True,
         Binding_Unit              => To_Unbounded_String ("Files.Accessibility"));
   end Integration_Profile;

   function Export_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return Export_Result
   is
      Result : Export_Result :=
        (Success                   => True,
         Native_API_Binding_Status => Files.File_System.Native_API_Binding_Missing,
         Node_Count                => Natural (Frame.Accessibility.Length),
         Focused_Node_Count        => 0,
         Nodes                     => Frame.Accessibility,
         Binding_Unit              => To_Unbounded_String ("Files.Accessibility"));
   begin
      for Node of Frame.Accessibility loop
         if Node.Focused then
            Result.Focused_Node_Count := Result.Focused_Node_Count + 1;
         end if;
      end loop;

      return Result;
   end Export_Tree;

end Files.Accessibility;
