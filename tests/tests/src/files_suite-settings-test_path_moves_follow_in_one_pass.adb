with Files.Settings.Path_References;
with Files.Settings.Path_References.Testing;
with Files.Preference_Types;
separate (Files_Suite.Settings)
   --  The moves a window queued (renames, moves, removals) are followed in
   --  one pass over the stored paths, and end where following them one at a
   --  time does: a label rides a chain of moves, a label at a place a
   --  labelled entry moved onto goes, a removed folder takes its own along,
   --  and a favorite moved onto one already listed is listed once. A move
   --  named in another normalization of a folder's name (é composed, the
   --  stored path decomposed, as HFS+ lists it) still takes what is inside.
   procedure Test_Path_Moves_Follow_In_One_Pass (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Refs renames Files.Settings.Path_References;
      use type Files.Preference_Types.Color_Label;
      Base     : constant String := Join (Root, "moves");
      A        : constant String := Join (Base, "a");
      B        : constant String := Join (Base, "b");
      C        : constant String := Join (Base, "c");
      D        : constant String := Join (Base, "d");
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Stepwise : Files.Settings.Settings_Model;
      Moves    : Files.Types.Path_Move_Vectors.Vector;
      Changed  : Boolean;

      procedure Queue (From, To : String; Kind : Files.Types.Path_Move_Kind) is
      begin
         Moves.Append
           (Files.Types.Path_Move'(From => To_Unbounded_String (From), To => To_Unbounded_String (To), Kind => Kind));
      end Queue;
   begin
      Refs.Testing.Set_Label (Settings, Join (A, "x"), Files.Preference_Types.Red);
      Refs.Testing.Set_Label (Settings, Join (C, "x"), Files.Preference_Types.Green);
      Refs.Testing.Set_Label (Settings, Join (D, "y"), Files.Preference_Types.Blue);
      Refs.Add_Favorite (Settings, A);
      Refs.Add_Favorite (Settings, C);
      Refs.Note_Recent (Settings, Join (D, "y"));
      Stepwise := Settings;

      Queue (A, B, Files.Types.Moved);
      Queue (B, C, Files.Types.Moved);
      Queue (D, "", Files.Types.Removed);
      Refs.Follow_Path_Moves (Settings, Moves, Changed);
      Assert (Changed, "the moves changed what is stored");

      Refs.Move_Path_References (Stepwise, A, B, Changed);
      Refs.Move_Path_References (Stepwise, B, C, Changed);
      Refs.Forget_Path_References (Stepwise, D, Changed);

      Assert (Refs.Label_Of (Settings, Join (C, "x")) = Files.Preference_Types.Red,
              "a label rides a chain of moves to its end");
      Assert (Refs.Label_Of (Settings, Join (A, "x")) = Files.Preference_Types.No_Label
              and then Refs.Label_Of (Settings, Join (B, "x")) = Files.Preference_Types.No_Label,
              "and leaves nothing on the way");
      Assert (Natural (Refs.Path_Labels (Settings).Length) = 1,
              "the label at the place it moved onto goes, and the removed folder's with it");
      Assert (Refs.Same_Labels (Stepwise, Refs.Path_Labels (Settings)), "the labels end as one at a time ends them");
      Assert (Refs.Same_Favorites (Stepwise, Refs.Favorite_Paths (Settings))
              and then Natural (Refs.Favorite_Paths (Settings).Length) = 1,
              "a favorite moved onto one listed is listed once, as one at a time lists it");
      Assert (Refs.Recent_Paths (Settings).Is_Empty, "a removed recent item goes");

      Refs.Testing.Simulate_Folding_Host (True);
      declare
         Composed   : constant String := Join (Root, "Caf" & Character'Val (16#C3#) & Character'Val (16#A9#));
         Decomposed : constant String := Join (Root, "Cafe" & Character'Val (16#CC#) & Character'Val (16#81#));
         Renamed    : constant String := Join (Root, "Bar");
         Spelled    : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      begin
         Refs.Testing.Set_Label (Spelled, Join (Decomposed, "n.txt"), Files.Preference_Types.Red);
         Assert (Refs.Label_Of (Spelled, Join (Composed, "n.txt")) = Files.Preference_Types.Red,
                 "the composed spelling finds the decomposed one's label");
         Refs.Move_Path_References (Spelled, Composed, Renamed, Changed);
         Assert (Changed and then Refs.Label_Of (Spelled, Join (Renamed, "n.txt")) = Files.Preference_Types.Red,
                 "a move named in the composed spelling takes the label along");
         Assert (Refs.Label_Of (Spelled, Join (Composed, "n.txt")) = Files.Preference_Types.No_Label,
                 "and leaves none at the old place");
      end;
      Refs.Testing.Simulate_Folding_Host (False);
   exception
      when others =>
         Refs.Testing.Simulate_Folding_Host (False);
         raise;
   end Test_Path_Moves_Follow_In_One_Pass;
