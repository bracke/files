with Ada.Strings.Unbounded;

with Files.File_System;
with Guikit.Draw;
with Files.Rendering;

with A11ykit.Tree;

--  Accessibility bridge for exporting render accessibility nodes.
package Files.Accessibility is

   type Export_Result is record
      Success                   : Boolean := False;
      Native_API_Binding_Status : Files.File_System.Native_API_Binding_Status :=
        Files.File_System.Native_API_Binding_Missing;
      Node_Count                : Natural := 0;
      Focused_Node_Count        : Natural := 0;
      Nodes                     : Guikit.Draw.Accessibility_Node_Vectors.Vector;
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

   --  Map the frame's flat accessibility nodes into a hierarchical A11ykit tree
   --  -- the toolkit-neutral form a screen-reader provider consumes -- inferring
   --  the parent/child structure from the nodes' geometry.
   --
   --  @param Frame Render frame containing accessibility nodes.
   --  @return The nodes as an A11ykit.Tree with inferred hierarchy and focus.
   function To_A11ykit_Tree
     (Frame : Files.Rendering.Frame_Commands)
      return A11ykit.Tree.Accessibility_Tree;

   --  Publish the frame's accessibility tree to the host screen-reader service
   --  when a provider is available. A no-op otherwise -- and no host provider is
   --  implemented yet, so it currently never publishes -- so it is safe (and
   --  cheap) to call every frame.
   --
   --  @param Frame Render frame containing accessibility nodes.
   procedure Publish (Frame : Files.Rendering.Frame_Commands);

end Files.Accessibility;
