with Files.Undo_Payloads;
separate (Files_Suite.Model)
   procedure Test_Undo_Payloads_Round_Trip (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use Files.Undo_Payloads;
      Written : constant Ownership :=
        (User_Id => 4_294_967_294, Group_Id => 0,
         User_Name => To_Unbounded_String ("nobody"), Group_Name => To_Unbounded_String ("root"));

      function Owner_Of (Text : String; Value : out Ownership) return Boolean renames Parse_Ownership;

      function Is_Ownership (Text : String) return Boolean is
         Value : Ownership;
      begin
         return Owner_Of (Text, Value);
      end Is_Ownership;

      function Is_Mode (Text : String) return Boolean is
         Mode : Natural;
      begin
         return Parse_Mode (Text, Mode);
      end Is_Mode;

      Read : Ownership;
      Mode : Natural;
   begin
      Assert (Owner_Of (Ownership_Text (Written), Read) and then Read = Written,
              "an ownership payload reads back with both ids (past Natural'Last too) and both names");
      Assert (Is_Ownership ("1000 100"), "the names are optional");
      Assert (not Is_Ownership ("1000"), "both ids are needed");
      Assert (not Is_Ownership ("1000 100" & ASCII.NUL & "me"), "the names come in pairs");
      Assert (not Is_Ownership ("1 2" & ASCII.NUL & "a" & ASCII.NUL & "b" & ASCII.NUL & "c"), "no third name");
      Assert (not Is_Ownership ("-1 2"), "no sign");

      Assert (Parse_Mode (Mode_Text (8#755#), Mode) and then Mode = 8#755#, "a mode payload reads back");
      Assert (Mode_Access (Mode_Text (8#755#)) = "", "with no access record where none was given");
      --  A Windows DACL, as Change_Access reports it, rides after the bits.
      Assert
        (Parse_Mode (Mode_Text (8#640#, "D:AI(A;;FA;;;SY)(A;ID;0x1200a9;;;BU)"), Mode) and then Mode = 8#640#,
         "a mode payload with an access record reads its bits back");
      Assert
        (Mode_Access (Mode_Text (8#640#, "D:AI(A;;FA;;;SY)(A;ID;0x1200a9;;;BU)"))
         = "D:AI(A;;FA;;;SY)(A;ID;0x1200a9;;;BU)",
         "and the record whole");
      Assert (Is_Mode (" 420" & ASCII.NUL & "D:P"), "a recorded payload is a mode payload");
      Assert (not Is_Mode (" 420" & ASCII.NUL & "D:P" & ASCII.NUL & "x"), "but not with a second NUL");
      Assert (not Is_Mode ("16#1ED#"), "no Ada literal syntax");
      Assert (not Is_Mode (""), "and not empty");
   end Test_Undo_Payloads_Round_Trip;
