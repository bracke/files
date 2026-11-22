separate (Check_All)
   procedure Check_CLDR_Importer is
   begin
      Run_And_Require_Output
        (Label           => "CLDR catalog importer fixture",
         Dir             => Root,
         Program         => Root & "/tools/bin/cldr_to_catalog",
         Args            =>
           [1 => new String'(Root & "/tools/testdata/cldr/main/zz.xml")],
         Output_Path     => Temp_Path ("cldr.out"),
         Required_First  => "zz-ZZ.time.weekday.monday = Monday Z",
         Required_Second => "zz-ZZ.details.size.unit.bytes = zb");
   end Check_CLDR_Importer;
