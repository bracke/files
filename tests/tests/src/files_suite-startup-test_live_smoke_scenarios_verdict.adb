separate (Files_Suite.Startup)
   procedure Test_Live_Smoke_Scenarios_Verdict (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);

      --  All scenarios pass and every scenario carries a distinct framebuffer
      --  hash, so every non-default scenario differs from the default frame.
      All_Distinct : Files.Application.Windows.Smoke.Scenario_Outcome_Array;
      Analysis_Fail : Files.Application.Windows.Smoke.Scenario_Outcome_Array;
      Duplicate     : Files.Application.Windows.Smoke.Scenario_Outcome_Array;
      Next_Hash     : Interfaces.Unsigned_32 := 100;
   begin
      for Scenario in Files.Application.Windows.Smoke.Live_Smoke_Scenario loop
         All_Distinct (Scenario) :=
           (Rendered       => True,
            Readback_Ready => True,
            Passed         => True,
            Hash           => Next_Hash,
            others         => <>);
         Next_Hash := Next_Hash + 1;
      end loop;

      Assert
        (Files.Application.Windows.Smoke.Scenarios_Verdict (All_Distinct),
         "all scenarios passing with distinct hashes yields an overall pass");

      --  A single scenario that failed structural analysis fails the aggregate.
      Analysis_Fail := All_Distinct;
      Analysis_Fail (Files.Application.Windows.Smoke.Scenario_Palette).Passed := False;
      Assert
        (not Files.Application.Windows.Smoke.Scenarios_Verdict (Analysis_Fail),
         "one scenario failing structural analysis fails the aggregate verdict");

      --  A non-default scenario whose frame is identical to the default frame
      --  (its state did not change the render) fails the aggregate verdict.
      Duplicate := All_Distinct;
      Duplicate (Files.Application.Windows.Smoke.Scenario_Selection).Hash :=
        Duplicate (Files.Application.Windows.Smoke.Scenario_Default).Hash;
      Assert
        (not Files.Application.Windows.Smoke.Scenarios_Verdict (Duplicate),
         "a non-default scenario identical to default fails the aggregate verdict");
      Assert
        (not Files.Application.Windows.Smoke.Scenario_Passed
              (Duplicate, Files.Application.Windows.Smoke.Scenario_Selection),
         "a non-default scenario identical to default is not a passing scenario");

      --  A scenario that structurally passed and differs from default but whose
      --  layout-derived region assertion found no ink fails the aggregate: the
      --  asserted UI element is missing from its computed pixel position.
      declare
         Region_Fail : Files.Application.Windows.Smoke.Scenario_Outcome_Array := All_Distinct;
      begin
         Region_Fail (Files.Application.Windows.Smoke.Scenario_Selection).Region_Checked := True;
         Region_Fail (Files.Application.Windows.Smoke.Scenario_Selection).Region_Ink_Present := False;
         Assert
           (not Files.Application.Windows.Smoke.Scenario_Passed
                 (Region_Fail, Files.Application.Windows.Smoke.Scenario_Selection),
            "an empty layout-derived region fails the scenario despite a structural pass");
         Assert
           (not Files.Application.Windows.Smoke.Scenarios_Verdict (Region_Fail),
            "an empty layout-derived region fails the aggregate verdict");

         --  The same region check passing keeps the scenario and aggregate green.
         Region_Fail (Files.Application.Windows.Smoke.Scenario_Selection).Region_Ink_Present := True;
         Assert
           (Files.Application.Windows.Smoke.Scenarios_Verdict (Region_Fail),
            "a region assertion that found ink keeps the aggregate verdict passing");
      end;
   end Test_Live_Smoke_Scenarios_Verdict;
