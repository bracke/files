with A11ykit;
with A11ykit.Provider;

package body Files.Accessibility is
   use Ada.Strings.Unbounded;

   --  The neutral roles line up one-to-one with the renderer's roles.
   function A11y_Role (Node_Role : Guikit.Draw.Accessibility_Role) return A11ykit.Role is
     (case Node_Role is
         when Guikit.Draw.Role_Window     => A11ykit.Role_Window,
         when Guikit.Draw.Role_Dialog     => A11ykit.Role_Dialog,
         when Guikit.Draw.Role_Pane       => A11ykit.Role_Pane,
         when Guikit.Draw.Role_Toolbar    => A11ykit.Role_Toolbar,
         when Guikit.Draw.Role_Button     => A11ykit.Role_Button,
         when Guikit.Draw.Role_Text_Input => A11ykit.Role_Text_Input,
         when Guikit.Draw.Role_List       => A11ykit.Role_List,
         when Guikit.Draw.Role_List_Item  => A11ykit.Role_List_Item,
         when Guikit.Draw.Role_Table      => A11ykit.Role_Table,
         when Guikit.Draw.Role_Table_Row  => A11ykit.Role_Table_Row,
         when Guikit.Draw.Role_Heading    => A11ykit.Role_Heading,
         when Guikit.Draw.Role_Status     => A11ykit.Role_Status);

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

   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree
   is
      Flat : A11ykit.Tree.Node_Vectors.Vector;
   begin
      for Node of Frame.Accessibility loop
         Flat.Append
           (A11ykit.Tree.Node'
              (Node_Role   => A11y_Role (Node.Role),
               Bounds      =>
                 (X      => Node.X,
                  Y      => Node.Y,
                  Width  => Node.Width,
                  Height => Node.Height),
               Name        => Node.Name,
               Description => Node.Description,
               Node_State  =>
                 (Enabled  => Node.Enabled,
                  Selected => Node.Selected,
                  Focused  => Node.Focused),
               Parent      => 0));
      end loop;

      return A11ykit.Tree.Build (Flat);
   end To_A11ykit_Tree;

   procedure Publish (Frame : Files.Rendering.Frame_Commands) is
   begin
      if A11ykit.Provider.Available then
         A11ykit.Provider.Publish (To_A11ykit_Tree (Frame));
      end if;
   end Publish;

end Files.Accessibility;
