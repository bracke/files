--  The helper process's side of an operation job: it runs the operation the
--  window asked for (Files.Operations) against a model of its own and
--  publishes what it did. Apart from the window's side so that side does not
--  depend on the operations it starts.
package Files.Operation_Jobs.Helper is

   --  Run the requested operation and publish its result.
   --  @param Directory Private request/result directory passed to the helper.
   procedure Run (Directory : String);

end Files.Operation_Jobs.Helper;
