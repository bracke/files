separate (Files_Suite.Operations)
   --  The desktop entry spec allows an escaped "%%" inside a quoted argument;
   --  the parser used to read its second '%' as the start of a field code and
   --  reject the whole Exec line.
   procedure Test_Desktop_Exec_Quoted_Percent (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      App     : constant Files.Desktop_Applications.Application :=
        (Name         => To_Unbounded_String ("Percent App"),
         Exec         => To_Unbounded_String ("printf ""100%% done"" %f"),
         Icon         => Null_Unbounded_String,
         Desktop_File => Null_Unbounded_String);
      Bad     : constant Files.Desktop_Applications.Application :=
        (Name         => To_Unbounded_String ("Field In Quotes"),
         Exec         => To_Unbounded_String ("printf ""%f"""),
         Icon         => Null_Unbounded_String,
         Desktop_File => Null_Unbounded_String);
      Targets : Files.Types.String_Vectors.Vector;
      Action  : Files.Settings.Open_Action;
   begin
      Targets.Append (To_Unbounded_String ("/tmp/a.txt"));
      Action := Files.Desktop_Applications.Build_Open_Action (App, Targets);
      Files_Suite.Support.Assert_Equal (To_String (Action.Executable), "printf", "the quoted %% line is accepted");
      Files_Suite.Support.Assert_Equal
        (Natural (Action.Arguments.Length), 2, "the quoted %% line keeps both arguments");
      Files_Suite.Support.Assert_Equal
        (To_String (Action.Arguments.Element (1)), "100% done", "a quoted %% becomes one percent sign");
      Files_Suite.Support.Assert_Equal
        (To_String (Action.Arguments.Element (2)), "/tmp/a.txt", "the field code after it still expands");

      --  A field code inside quotes is still refused.
      Action := Files.Desktop_Applications.Build_Open_Action (Bad, Targets);
      Files_Suite.Support.Assert_Equal (To_String (Action.Executable), "", "a quoted field code is rejected");
   end Test_Desktop_Exec_Quoted_Percent;
