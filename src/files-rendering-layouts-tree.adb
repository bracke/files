with Ada.Containers;
with Ada.Strings;
with Ada.Strings.Unbounded;

with Files.Rendering.Geometry;

package body Files.Rendering.Layouts.Tree is

   use Files.Rendering.Geometry;
   use Ada.Strings.Unbounded;

   function Calculate_Tree_Row_Layout
     (Snapshot    : View_Snapshot;
      Layout      : Tree_Panel_Layout;
      Line_Height : Positive)
      return Tree_Row_Layout_Vectors.Vector
 is separate;

   function Tree_Pick_Buttons (Panel : Tree_Panel_Layout) return Tree_Pick_Button_Layout is separate;

end Files.Rendering.Layouts.Tree;
