separate (Files_Suite.Startup)
   procedure Test_Fractional_Scroll_Accumulation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Scroll_Remainder : Long_Float := 0.0;
      Scroll_Lines     : Integer;
   begin
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, 0.40);
      Files_Suite.Support.Assert_Equal (Scroll_Lines, 0, "fractional scroll starts below one line");
      Assert (abs (Scroll_Remainder - 0.40) < 0.000_001, "fractional scroll remainder is retained");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, 0.35);
      Files_Suite.Support.Assert_Equal (Scroll_Lines, 0, "second fractional scroll can still be below one line");
      Assert (abs (Scroll_Remainder - 0.75) < 0.000_001, "second fractional scroll accumulates");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, 0.50);
      Files_Suite.Support.Assert_Equal (Scroll_Lines, 1, "fractional scroll emits a whole line after accumulation");
      Assert (abs (Scroll_Remainder - 0.25) < 0.000_001, "fractional scroll keeps positive remainder");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, -0.75);
      Files_Suite.Support.Assert_Equal (Scroll_Lines, 0, "opposite fractional scroll can cancel without a line");
      Assert (abs (Scroll_Remainder + 0.50) < 0.000_001, "opposite fractional scroll keeps negative remainder");
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, -0.75);
      Files_Suite.Support.Assert_Equal
        (Scroll_Lines,
         -1,
         "negative fractional scroll emits a whole line after accumulation");
      Assert (abs (Scroll_Remainder + 0.25) < 0.000_001, "fractional scroll keeps negative remainder");
      Scroll_Remainder := 0.0;
      Scroll_Lines := Files.Application.Windows.Accumulate_Scroll_Offset (Scroll_Remainder, Long_Float (Integer'Last));
      Files_Suite.Support.Assert_Equal
        (Scroll_Lines,
         Integer'Last,
         "scroll accumulation saturates large positive offsets");
      Assert (Scroll_Remainder = 0.0, "saturated scroll clears remainder");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Add_Pending_Scroll (Integer'Last - 1, 2),
         Integer'Last,
         "pending scroll addition saturates positive overflow");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Add_Pending_Scroll (Integer'First + 1, -2),
         Integer'First,
         "pending scroll addition saturates negative overflow");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Windows.Add_Pending_Scroll (4, -6),
         -2,
         "pending scroll addition preserves normal mixed-sign sums");
   end Test_Fractional_Scroll_Accumulation;
