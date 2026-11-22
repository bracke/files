with A11ykit.Provider;
with Files.Application.Window_Policy;
with Files.Preference_Types;
separate (Files_Suite.Rendering)
   --  While no assistive technology listens, each window's changed tree is
   --  published at most once per quiet interval, counted per window: one
   --  window that changes every frame does not keep another's waiting.
   procedure Test_A11y_Quiet_Publish_Per_Window (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      package Accessibility renames Files.Application.Accessibility;

      function Frame_Of (Count : Positive) return Frame_Commands is
        (Build_Frame_Commands
           (Sample_Snapshot (Count, Files.Preference_Types.Small_Icons),
            Width => 800, Height => 600, Line_Height => 20));

      Two    : constant Frame_Commands := Frame_Of (2);
      Three  : constant Frame_Commands := Frame_Of (3);
      Four   : constant Frame_Commands := Frame_Of (4);
      Busy   : constant Accessibility.Window_Key := Accessibility.New_Window_Key;
      Quiet  : constant Accessibility.Window_Key := Accessibility.New_Window_Key;
   begin
      Accessibility.Start;
      --  A window's first tree is published at once.
      Accessibility.Publish (Busy, Two);
      Accessibility.Publish (Quiet, Two);
      Files_Suite.Support.Assert_Equal (Accessibility.Testing.Published_Windows, 2, "both first trees published");
      if not A11ykit.Provider.Listening then
         Accessibility.Publish (Busy, Three);
         Files_Suite.Support.Assert_Equal
           (Accessibility.Testing.Waiting_Windows, 1, "a change within the quiet interval waits");
      end if;
      delay Files.Application.Window_Policy.Quiet_Publish_Interval + 0.1;
      --  The busy window's change goes out; the quiet window's, coming
      --  right after it, is due by its own interval too.
      Accessibility.Publish (Busy, Four);
      Files_Suite.Support.Assert_Equal
        (Accessibility.Testing.Waiting_Windows, 0, "a change after the quiet interval is published");
      Accessibility.Publish (Quiet, Three);
      Files_Suite.Support.Assert_Equal
        (Accessibility.Testing.Waiting_Windows, 0,
         "one window's publish does not hold back another window's change");
      Accessibility.Forget (Busy);
      Accessibility.Forget (Quiet);
      Accessibility.Stop;
   exception
      when others =>
         Accessibility.Stop;
         raise;
   end Test_A11y_Quiet_Publish_Per_Window;
