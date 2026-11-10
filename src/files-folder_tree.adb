with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

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

   --  A detached node's parent: no node, and not a root (0).
   Detached : constant Natural := Natural'Last;

   procedure Replace_Children
     (T        : in out Tree;
      Index    : Positive;
      Children : Entry_Seed_Vectors.Vector) is
   begin
      if not In_Range (T, Index) then
         return;
      end if;
      for Child of T.Nodes loop
         if Child.Parent = Index then
            Child.Parent := Detached;
         end if;
      end loop;
      T.Nodes (Index).Loaded := False;
      Set_Children (T, Index, Children);
   end Replace_Children;

   function Same_Roots
     (T     : Tree;
      Roots : Entry_Seed_Vectors.Vector)
      return Boolean
   is
      Next : Natural := Roots.First_Index;
   begin
      for N of T.Nodes loop
         if N.Parent = 0 then
            if Next > Roots.Last_Index
              or else N.Path /= Roots (Next).Path
              or else N.Name /= Roots (Next).Name
            then
               return False;
            end if;
            Next := Next + 1;
         end if;
      end loop;
      return Next > Roots.Last_Index;
   end Same_Roots;

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
   begin
      if T.Nodes.Is_Empty then
         return Result;
      end if;

      declare
         subtype Node_Range is Positive range T.Nodes.First_Index .. T.Nodes.Last_Index;
         type Link_Array is array (Node_Range) of Natural;
         type Link_Array_Access is access Link_Array;
         procedure Free is new Ada.Unchecked_Deallocation (Link_Array, Link_Array_Access);
         --  Children of each node as a linked list in attach order, built in
         --  one pass. Scanning every node per expanded node made a deeply
         --  expanded tree quadratic on every snapshot. On the heap: sized by
         --  the node count, three of them overflow a 1 MiB stack (Windows'
         --  main thread) at under 90,000 nodes.
         First_Child : Link_Array_Access := new Link_Array'[others => 0];
         Last_Child  : Link_Array_Access := new Link_Array'[others => 0];
         Next_Child  : Link_Array_Access := new Link_Array'[others => 0];

         procedure Visit (Index : Positive) is
            N     : Node renames T.Nodes (Index);
            Child : Natural;
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
               Child := First_Child (Index);
               while Child /= 0 loop
                  Visit (Child);
                  Child := Next_Child (Child);
               end loop;
            end if;
         end Visit;
      begin
         for Index in Node_Range loop
            declare
               Parent : constant Natural := T.Nodes (Index).Parent;
            begin
               if Parent in Node_Range then
                  if First_Child (Parent) = 0 then
                     First_Child (Parent) := Index;
                  else
                     Next_Child (Last_Child (Parent)) := Index;
                  end if;
                  Last_Child (Parent) := Index;
               end if;
            end;
         end loop;
         for Index in Node_Range loop
            if T.Nodes (Index).Parent = 0 then
               Visit (Index);
            end if;
         end loop;
         Free (First_Child);
         Free (Last_Child);
         Free (Next_Child);
      exception
         when others =>
            Free (First_Child);
            Free (Last_Child);
            Free (Next_Child);
            raise;
      end;
      return Result;
   end Visible_Rows;

   function Visible_Row_Count
     (T : Tree)
      return Natural
   is
      type Flag_Array is array (Positive range <>) of Boolean;
      type Flag_Array_Access is access Flag_Array;
      procedure Free is new Ada.Unchecked_Deallocation (Flag_Array, Flag_Array_Access);
      Count : Natural := 0;
   begin
      if T.Nodes.Is_Empty then
         return 0;
      end if;

      declare
         --  Set_Children appends children after their parent, so one forward
         --  pass sees each parent's visibility before any of its children.
         --  On the heap, as Visible_Rows' links are.
         Shown : Flag_Array_Access :=
           new Flag_Array'[T.Nodes.First_Index .. T.Nodes.Last_Index => False];
      begin
         for Index in Shown'Range loop
            declare
               Parent : constant Natural := T.Nodes.Element (Index).Parent;
            begin
               Shown (Index) :=
                 Parent = 0
                 or else (Parent < Index
                          and then Shown (Parent)
                          and then T.Nodes.Element (Parent).Expanded);
               if Shown (Index) then
                  Count := Count + 1;
               end if;
            end;
         end loop;
         Free (Shown);
      exception
         when others =>
            Free (Shown);
            raise;
      end;
      return Count;
   end Visible_Row_Count;

end Files.Folder_Tree;
