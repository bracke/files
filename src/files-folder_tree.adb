with Ada.Containers.Generic_Array_Sort;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Unchecked_Deallocation;

package body Files.Folder_Tree is
   use Ada.Strings.Unbounded;

   procedure Changed (T : in out Tree);

   --  Revisions are drawn process-wide, so two trees (another window's, a
   --  tree seeded again) never share one: a revision names one set of rows.
   protected Revisions is
      procedure Next (Revision : out Positive);
   private
      Last : Natural := 0;
   end Revisions;

   protected body Revisions is
      procedure Next (Revision : out Positive) is
      begin
         Last := (if Last = Natural'Last then 1 else Last + 1);
         Revision := Last;
      end Next;
   end Revisions;

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
               Has_Children => True,
               Loading      => False,
               Rank         => 0));
      end loop;
      T.Seeded := True;
      Changed (T);
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

   function Node_Is_Expanded
     (T     : Tree;
      Index : Positive)
      return Boolean is
   begin
      return In_Range (T, Index) and then T.Nodes.Element (Index).Expanded;
   end Node_Is_Expanded;

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
      declare
         package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
           (Key_Type        => String,
            Element_Type    => Positive,
            Hash            => Ada.Strings.Hash,
            Equivalent_Keys => "=");
         Attached     : Index_Maps.Map;
         Kept         : Index_Maps.Map;
         Parent_Depth : constant Natural := T.Nodes (Index).Depth;
         Rank         : Natural := 0;
      begin
         for Child_Index in T.Nodes.First_Index .. T.Nodes.Last_Index loop
            if T.Nodes (Child_Index).Parent = Index then
               Attached.Include (To_String (T.Nodes (Child_Index).Path), Child_Index);
            end if;
         end loop;
         for Child of Children loop
            Rank := Rank + 1;
            declare
               Path  : constant String := To_String (Child.Path);
               Found : constant Index_Maps.Cursor := Attached.Find (Path);
            begin
               if Index_Maps.Has_Element (Found) and then not Kept.Contains (Path) then
                  T.Nodes (Index_Maps.Element (Found)).Name := Child.Name;
                  T.Nodes (Index_Maps.Element (Found)).Rank := Rank;
                  --  A folder that was empty when read may not be now: like a
                  --  child never read, it offers its expander again.
                  if T.Nodes (Index_Maps.Element (Found)).Loaded
                    and then not T.Nodes (Index_Maps.Element (Found)).Has_Children
                  then
                     T.Nodes (Index_Maps.Element (Found)).Loaded := False;
                     T.Nodes (Index_Maps.Element (Found)).Has_Children := True;
                  end if;
                  Kept.Insert (Path, Index_Maps.Element (Found));
               else
                  T.Nodes.Append
                    (Node'
                       (Path         => Child.Path,
                        Name         => Child.Name,
                        Depth        => Parent_Depth + 1,
                        Parent       => Index,
                        Expanded     => False,
                        Loaded       => False,
                        Has_Children => True,
                        Loading      => False,
                        Rank         => Rank));
               end if;
            end;
         end loop;
         for Position in Attached.Iterate loop
            if not Kept.Contains (Index_Maps.Key (Position)) then
               T.Nodes (Index_Maps.Element (Position)).Parent := Detached;
            end if;
         end loop;
         T.Nodes (Index).Loaded := True;
         T.Nodes (Index).Loading := False;
         T.Nodes (Index).Has_Children := not Children.Is_Empty;
      end;
      Changed (T);
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
      Changed (T);
   end Set_Expanded;

   procedure Set_Loading
     (T       : in out Tree;
      Index   : Positive;
      Loading : Boolean) is
   begin
      if In_Range (T, Index) and then T.Nodes (Index).Loading /= Loading then
         T.Nodes (Index).Loading := Loading;
         --  Only the node's row changes: patched in place, not flattened
         --  again (a large expanded tree took tens of milliseconds).
         for Row of T.Rows loop
            if Row.Node_Index = Index then
               Row.Loading := Loading;
               exit;
            end if;
         end loop;
         declare
            Revision : Positive;
         begin
            Revisions.Next (Revision);
            T.Revision := Revision;
         end;
      end if;
   end Set_Loading;

   procedure Toggle_Expanded
     (T     : in out Tree;
      Index : Positive) is
   begin
      if not In_Range (T, Index) then
         return;
      end if;
      Set_Expanded (T, Index, not T.Nodes.Element (Index).Expanded);
   end Toggle_Expanded;

   --  The visible rows, flattened from the nodes.
   --
   --  @param T Tree to project.
   --  @return Visible rows in top-to-bottom display order.
   function Flatten
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
                  Has_Children => N.Has_Children,
                  Loading      => N.Loading));
            if N.Expanded then
               declare
                  Count : Natural := 0;
               begin
                  Child := First_Child (Index);
                  while Child /= 0 loop
                     Count := Count + 1;
                     Child := Next_Child (Child);
                  end loop;
                  declare
                     type Child_Array is array (Positive range <>) of Positive;
                     function Before (Left, Right : Positive) return Boolean is
                       (T.Nodes (Left).Rank < T.Nodes (Right).Rank);
                     procedure Sort is new Ada.Containers.Generic_Array_Sort
                       (Index_Type   => Positive,
                        Element_Type => Positive,
                        Array_Type   => Child_Array,
                        "<"          => Before);
                     --  On the heap: a folder can hold more subfolders than
                     --  a small stack has room for.
                     type Child_Array_Access is access Child_Array;
                     procedure Free is new Ada.Unchecked_Deallocation (Child_Array, Child_Array_Access);
                     Ordered : Child_Array_Access := new Child_Array (1 .. Count);
                  begin
                     Child := First_Child (Index);
                     for Slot of Ordered.all loop
                        Slot := Child;
                        Child := Next_Child (Child);
                     end loop;
                     --  In listing order, which a re-read can change for kept children.
                     Sort (Ordered.all);
                     for Item of Ordered.all loop
                        Visit (Item);
                     end loop;
                     Free (Ordered);
                  exception
                     when others =>
                        Free (Ordered);
                        raise;
                  end;
               end;
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
   end Flatten;

   --  After a change to the nodes: the rows flattened again, the revision
   --  moved.
   --
   --  @param T Tree just changed.

   procedure Changed (T : in out Tree) is
      Revision : Positive;
   begin
      T.Rows := Flatten (T);
      Revisions.Next (Revision);
      T.Revision := Revision;
   end Changed;

   function Visible_Rows
     (T : Tree)
      return Visible_Row_Vectors.Vector is (T.Rows);

   function Structure_Revision
     (T : Tree)
      return Natural is (T.Revision);

   function Visible_Row_Count
     (T : Tree)
      return Natural is (Natural (T.Rows.Length));

end Files.Folder_Tree;
