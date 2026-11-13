separate (Files_Suite.Interaction)
   --  The cross-window settings sync (Files.Settings_Sharing.Share_From, as
   --  Files.Application.Windows.Share_Settings_From runs it after every
   --  window's step) over three stand-in windows: a change in one reaches
   --  each other window exactly once and never its own, the next pass
   --  re-applies nothing -- not even a change the adoption itself counted --
   --  and two windows changing in turn leave every window with the latest.
   procedure Test_Settings_Shared_Once_Across_Windows (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  A window: its settings stand-in (Value), its settings revision and
      --  synced mark, and what it adopted.
      type Fake_Window is record
         Value        : Natural := 0;
         Revision     : Natural := 0;
         Synced       : Natural := 0;
         Adoptions    : Natural := 0;
         Adopted_From : Natural := 0;
      end record;

      type Fake_Windows is array (Positive range <>) of Fake_Window;

      --  The settings value each window's step sets; zero leaves it be.
      type Changes is array (Positive range <>) of Natural;

      function Revision (Windows : Fake_Windows; Index : Positive) return Natural is (Windows (Index).Revision);

      function Synced_Revision (Windows : Fake_Windows; Index : Positive) return Natural is (Windows (Index).Synced);

      procedure Mark_Synced (Windows : in out Fake_Windows; Index : Positive; At_Revision : Natural) is
      begin
         Windows (Index).Synced := At_Revision;
      end Mark_Synced;

      --  Adopting counts as a change of the target's own, as a real one may:
      --  the sync must not hand it back.
      procedure Adopt (Windows : in out Fake_Windows; Target : Positive; Source : Positive) is
      begin
         Windows (Target).Value := Windows (Source).Value;
         Windows (Target).Adoptions := Windows (Target).Adoptions + 1;
         Windows (Target).Adopted_From := Source;
         Windows (Target).Revision := Windows (Target).Revision + 1;
      end Adopt;

      procedure Share is new Files.Settings_Sharing.Share_From
        (Window_Set      => Fake_Windows,
         Revision        => Revision,
         Synced_Revision => Synced_Revision,
         Mark_Synced     => Mark_Synced,
         Adopt           => Adopt);

      --  One event-loop pass (For_Each_Window): each window takes its step,
      --  then shares from it at once.
      procedure Pass (Windows : in out Fake_Windows; Step : Changes) is
      begin
         for Index in Windows'Range loop
            if Step (Index) /= 0 then
               Windows (Index).Value := Step (Index);
               Windows (Index).Revision := Windows (Index).Revision + 1;
            end if;
            Share (Windows, Windows'First, Windows'Last, Index);
         end loop;
      end Pass;

      function Adoptions (Windows : Fake_Windows) return Natural is
         Total : Natural := 0;
      begin
         for Window of Windows loop
            Total := Total + Window.Adoptions;
         end loop;
         return Total;
      end Adoptions;

      Windows : Fake_Windows (1 .. 3);
      Lone    : Fake_Windows (1 .. 1);
   begin
      Pass (Windows, [0, 0, 0]);
      Files_Suite.Support.Assert_Equal (Adoptions (Windows), 0, "windows with no change share nothing");

      Pass (Windows, [7, 0, 0]);
      Files_Suite.Support.Assert_Equal (Windows (1).Adoptions, 0, "the source window does not adopt its own change");
      Assert (Windows (2).Adoptions = 1 and then Windows (2).Adopted_From = 1 and then Windows (2).Value = 7,
              "the change in window 1 reaches window 2 once");
      Assert (Windows (3).Adoptions = 1 and then Windows (3).Adopted_From = 1 and then Windows (3).Value = 7,
              "the change in window 1 reaches window 3 once");

      Pass (Windows, [0, 0, 0]);
      Pass (Windows, [0, 0, 0]);
      Files_Suite.Support.Assert_Equal
        (Adoptions (Windows), 2, "later passes do not apply the change again, nor hand an adoption back");

      --  Window 2 changes, then window 3 in the same pass.
      Pass (Windows, [0, 8, 9]);
      for Index in Windows'Range loop
         Files_Suite.Support.Assert_Equal
           (Windows (Index).Value, 9, "two windows changing in turn leave every window with the latest change");
      end loop;
      Assert (Windows (2).Adopted_From = 3 and then Windows (1).Adopted_From = 3,
              "the later change is the one the other windows adopted last");
      Files_Suite.Support.Assert_Equal
        (Windows (3).Adoptions, 2, "window 3 took window 2's change once, its own never");
      Pass (Windows, [0, 0, 0]);
      Files_Suite.Support.Assert_Equal (Adoptions (Windows), 6, "after the two changes the windows settle");

      --  A lone window only catches up its mark.
      Pass (Lone, [5]);
      Assert (Lone (1).Adoptions = 0 and then Lone (1).Synced = Lone (1).Revision,
              "a lone window adopts nothing and only catches up its mark");
   end Test_Settings_Shared_Once_Across_Windows;
