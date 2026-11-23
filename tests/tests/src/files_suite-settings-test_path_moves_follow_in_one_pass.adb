with Ada.Containers;
with Files.Settings.Path_References;
with Files.Settings.Path_References.Testing;
with Files.Preference_Types;
separate (Files_Suite.Settings)
   --  The moves a window queued (renames, moves, removals) are followed in
   --  one pass over the stored paths, to the places written out below: a
   --  label rides a chain of moves, a label at a place a labelled entry
   --  moved onto goes, a removed folder takes its own along, a renamed file
   --  keeps its own label, a sibling whose name merely starts like a moved
   --  folder's stays, and a favorite moved onto one already listed is listed
   --  once. A move named in another normalization of a folder's name (é
   --  composed, the stored path decomposed, as HFS+ lists it) still takes
   --  what is inside, in a batch with another move.
   procedure Test_Path_Moves_Follow_In_One_Pass (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Refs renames Files.Settings.Path_References;
      use type Files.Preference_Types.Color_Label;
      use type Ada.Containers.Count_Type;
      use type Files.Settings.Path_Label_Vectors.Vector;
      Base     : constant String := Join (Root, "moves");
      A        : constant String := Join (Base, "a");
      AB       : constant String := Join (Base, "ab");
      B        : constant String := Join (Base, "b");
      C        : constant String := Join (Base, "c");
      D        : constant String := Join (Base, "d");
      E        : constant String := Join (Base, "e.txt");
      F        : constant String := Join (Base, "f.txt");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Moves    : Files.Types.Path_Move_Vectors.Vector;
      Changed  : Boolean;

      procedure Queue (From, To : String; Kind : Files.Types.Path_Move_Kind) is
      begin
         Moves.Append
           (Files.Types.Path_Move'(From => To_Unbounded_String (From), To => To_Unbounded_String (To), Kind => Kind));
      end Queue;

      --  Whether the stored labels are exactly Expected, in any order.
      function Labels_Are (Expected : Files.Settings.Path_Label_Vectors.Vector) return Boolean is
         Stored : constant Files.Settings.Path_Label_Vectors.Vector := Refs.Path_Labels (Settings);
      begin
         if Stored.Length /= Expected.Length then
            return False;
         end if;
         for Want of Expected loop
            if not (for some Have of Stored => Have.Path = Want.Path and then Have.Label = Want.Label) then
               return False;
            end if;
         end loop;
         return True;
      end Labels_Are;

      function Label (Path : String; Color : Files.Preference_Types.Color_Label) return Files.Settings.Path_Label is
        ((Path => To_Unbounded_String (Path), Label => Color));
   begin
      Refs.Testing.Set_Label (Settings, Join (A, "x"), Files.Preference_Types.Red);
      Refs.Testing.Set_Label (Settings, Join (C, "x"), Files.Preference_Types.Green);
      Refs.Testing.Set_Label (Settings, Join (D, "y"), Files.Preference_Types.Blue);
      Refs.Testing.Set_Label (Settings, Join (AB, "z"), Files.Preference_Types.Yellow);
      Refs.Testing.Set_Label (Settings, E, Files.Preference_Types.Purple);
      Refs.Add_Favorite (Settings, A);
      Refs.Add_Favorite (Settings, C);
      Refs.Note_Recent (Settings, Join (D, "y"));
      Refs.Note_Recent (Settings, E);

      Queue (A, B, Files.Types.Moved);
      Queue (B, C, Files.Types.Moved);
      Queue (D, "", Files.Types.Removed);
      Queue (E, F, Files.Types.Moved);
      Refs.Follow_Path_Moves (Settings, Moves, Changed);
      Assert (Changed, "the moves changed what is stored");

      Assert (Labels_Are
                (Files.Settings.Path_Label_Vectors.Empty_Vector
                 & Label (Join (C, "x"), Files.Preference_Types.Red)
                 & Label (Join (AB, "z"), Files.Preference_Types.Yellow)
                 & Label (F, Files.Preference_Types.Purple)),
              "the labels end at the chain's end (the one there goes), the removed folder's gone,"
              & " the renamed file's with it, and the look-alike sibling's untouched");
      Assert (Natural (Refs.Favorite_Paths (Settings).Length) = 1
              and then To_String (Refs.Favorite_Paths (Settings).First_Element) = C,
              "a favorite moved onto one listed is listed once");
      Assert (Natural (Refs.Recent_Paths (Settings).Length) = 1
              and then To_String (Refs.Recent_Paths (Settings).First_Element) = F,
              "a removed recent item goes, a renamed one follows");

      Moves.Clear;
      Refs.Follow_Path_Moves (Settings, Moves, Changed);
      Assert (not Changed, "no moves change nothing");

      Refs.Testing.Simulate_Folding_Host (True);
      declare
         Composed   : constant String := Join (Root, "Caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
         Decomposed : constant String := Join (Root, "Cafe" & Character'Val (16#CC#) & Character'Val (16#81#));
         Renamed    : constant String := Join (Root, "Bar");
         Other      : constant String := Join (Root, "Other");
         Other_To   : constant String := Join (Root, "Elsewhere");
      begin
         Settings := Files.Settings.Default_Settings;
         Refs.Testing.Set_Label (Settings, Join (Decomposed, "n.txt"), Files.Preference_Types.Red);
         Refs.Testing.Set_Label (Settings, Join (Other, "m.txt"), Files.Preference_Types.Green);
         Assert (Refs.Label_Of (Settings, Join (Composed, "n.txt")) = Files.Preference_Types.Red,
                 "the composed spelling finds the decomposed one's label");
         Queue (Other, Other_To, Files.Types.Moved);
         Queue (Composed, Renamed, Files.Types.Moved);
         Refs.Follow_Path_Moves (Settings, Moves, Changed);
         Assert (Changed, "the batch changed what is stored");
         Assert (Labels_Are
                   (Files.Settings.Path_Label_Vectors.Empty_Vector
                    & Label (Join (Renamed, "n.txt"), Files.Preference_Types.Red)
                    & Label (Join (Other_To, "m.txt"), Files.Preference_Types.Green)),
                 "a move named in the composed spelling takes the decomposed label along, beside another move");
      end;
      Refs.Testing.Simulate_Folding_Host (False);
   exception
      when others =>
         Refs.Testing.Simulate_Folding_Host (False);
         raise;
   end Test_Path_Moves_Follow_In_One_Pass;
