with Ada.Strings.Unbounded;

package body Files.Folder_Tree is
   use Ada.Strings.Unbounded;

   procedure Seed
     (T     : out Tree;
      Roots : Entry_Seed_Vectors.Vector) is
   begin
      T.Nodes.Clear;
      for Root of Roots loop
         T.Nodes.Append
           (Node'
              (Path         => Root.Path,
               Name         => Root.Name,
               Depth        => 0,
               Parent       => 0,
               Expanded     => False,
               Loaded       => False,
               Has_Children => True));
      end loop;
      T.Seeded := True;
   end Seed;

   function Is_Seeded
     (T : Tree)
      return Boolean is
   begin
      return T.Seeded;
   end Is_Seeded;

   function Node_Count
     (T : Tree)
      return Natural is
   begin
      return Natural (T.Nodes.Length);
   end Node_Count;

   function In_Range
     (T     : Tree;
      Index : Positive)
      return Boolean is
   begin
      return not T.Nodes.Is_Empty and then Index <= T.Nodes.Last_Index;
   end In_Range;

   function Node_Path
     (T     : Tree;
      Index : Positive)
      return String is
   begin
      if not In_Range (T, Index) then
         return "";
      end if;
      return To_String (T.Nodes.Element (Index).Path);
   end Node_Path;

   function Node_Is_Loaded
     (T     : Tree;
      Index : Positive)
      return Boolean is
   begin
      return In_Range (T, Index) and then T.Nodes.Element (Index).Loaded;
   end Node_Is_Loaded;

   function Node_Is_Expanded
     (T     : Tree;
      Index : Positive)
      return Boolean is
   begin
      return In_Range (T, Index) and then T.Nodes.Element (Index).Expanded;
   end Node_Is_Expanded;

   function Index_For_Path
     (T    : Tree;
      Path : String)
      return Natural is
   begin
      if T.Nodes.Is_Empty then
         return 0;
      end if;
      for I in T.Nodes.First_Index .. T.Nodes.Last_Index loop
         if To_String (T.Nodes.Element (I).Path) = Path then
            return I;
         end if;
      end loop;
      return 0;
   end Index_For_Path;

   procedure Set_Children
     (T        : in out Tree;
      Index    : Positive;
      Children : Entry_Seed_Vectors.Vector) is
   begin
      if not In_Range (T, Index) or else T.Nodes.Element (Index).Loaded then
         return;
      end if;

      declare
         Parent_Depth : constant Natural := T.Nodes.Element (Index).Depth;
      begin
         for Child of Children loop
            T.Nodes.Append
              (Node'
                 (Path         => Child.Path,
                  Name         => Child.Name,
                  Depth        => Parent_Depth + 1,
                  Parent       => Index,
                  Expanded     => False,
                  Loaded       => False,
                  Has_Children => True));
         end loop;
      end;

      declare
         Parent_Node : Node := T.Nodes.Element (Index);
      begin
         Parent_Node.Loaded := True;
         Parent_Node.Has_Children := not Children.Is_Empty;
         T.Nodes.Replace_Element (Index, Parent_Node);
      end;
   end Set_Children;

   procedure Set_Expanded
     (T        : in out Tree;
      Index    : Positive;
      Expanded : Boolean) is
   begin
      if not In_Range (T, Index) then
         return;
      end if;
      declare
         Target : Node := T.Nodes.Element (Index);
      begin
         Target.Expanded := Expanded;
         T.Nodes.Replace_Element (Index, Target);
      end;
   end Set_Expanded;

   procedure Toggle_Expanded
     (T     : in out Tree;
      Index : Positive) is
   begin
      if not In_Range (T, Index) then
         return;
      end if;
      Set_Expanded (T, Index, not T.Nodes.Element (Index).Expanded);
   end Toggle_Expanded;

   function Visible_Rows
     (T : Tree)
      return Visible_Row_Vectors.Vector
   is
      Result : Visible_Row_Vectors.Vector;

      procedure Visit (Index : Positive) is
         N : constant Node := T.Nodes.Element (Index);
      begin
         Result.Append
           (Visible_Row'
              (Node_Index   => Index,
               Path         => N.Path,
               Name         => N.Name,
               Depth        => N.Depth,
               Expanded     => N.Expanded,
               Loaded       => N.Loaded,
               Has_Children => N.Has_Children));
         if N.Expanded then
            for Child in T.Nodes.First_Index .. T.Nodes.Last_Index loop
               if T.Nodes.Element (Child).Parent = Index then
                  Visit (Child);
               end if;
            end loop;
         end if;
      end Visit;
   begin
      if T.Nodes.Is_Empty then
         return Result;
      end if;
      for Index in T.Nodes.First_Index .. T.Nodes.Last_Index loop
         if T.Nodes.Element (Index).Parent = 0 then
            Visit (Index);
         end if;
      end loop;
      return Result;
   end Visible_Rows;

end Files.Folder_Tree;
