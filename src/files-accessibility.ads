with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Rendering;

--  Accessibility bridge for exporting render accessibility nodes.
package Files.Accessibility is

   type Export_Result is record
      Success                   : Boolean := False;
      Native_API_Binding_Status : Files.File_System.Native_API_Binding_Status :=
        Files.File_System.Native_API_Binding_Missing;
      Node_Count                : Natural := 0;
      Focused_Node_Count        : Natural := 0;
      Nodes                     : Files.Rendering.Accessibility_Node_Vectors.Vector;
      Binding_Unit              : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   --  Return the accessibility integration profile for the current bridge.
   --
   --  @return Accessibility integration feature flags.
   function Integration_Profile return Files.Rendering.Accessibility_Integration_Profile;

   --  Export frame accessibility metadata as a stable bridge tree.
   --
   --  @param Frame Render frame containing accessibility nodes.
   --  @return Export result with copied nodes and bridge metadata.
   function Export_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return Export_Result;

end Files.Accessibility;
