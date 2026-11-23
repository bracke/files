with Files.Jobs.Process;

--  What the suite reaches of Files.Jobs.Context that is not part of its
--  interface.
package Files.Jobs.Context.Testing is

   --  Clean_Stages over Job's transport, under the lease Job holds on it;
   --  nothing for a session not reserved.
   --  @param Job The session whose stage records are cleaned.
   procedure Clean_Session_Stages (Job : Files.Jobs.Process.Session);

end Files.Jobs.Context.Testing;
