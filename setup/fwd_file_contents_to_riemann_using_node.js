var ArgumentParser = require('argparse').ArgumentParser;

var parser = new ArgumentParser({
    version: '1.0.0',
    addHelp: true});

parser.addArgument(
    [ '-f', '--file'],
    { help: 'input text file parse'});

var args = parser.parseArgs();

if (!args.file || args.file === '') {
  console.log('input file name is missing');
  return;
}

var rl = require('readline').createInterface({
  input: require('fs').createReadStream(args.file)
});

var client = require('riemann').createClient({
  host: '127.0.0.1',
  port: 15555
});

client.on('connect', function() {
  console.log('connected!');
  });

client.on('disconnect', function(){
     console.log('disconnected!');
   });

function sendRiemann(cli, line) {
  cli.send(cli.Event({
      service:'plumgrid',
      tags:['NRV'],
      metric: 1.0,
      description:line
  }), cli.tcp);
}

var first = 0;
client.on('data', function(ack) {
  first ++;
  if ((first % 100) == 9)
  console.log('ACK cnt = ' + first);
});

rl.on('line', function(message) {
  // Our riemann server expects to have a message in below format (a complete syslog message).
  //; "2016-01-04T23:16:43.021Z 127.0.0.1 {2016-01-04T23:16:43.019273+00:00,tahir-ahmed-b-1-bld-master, service_directory_2fa5b111 [10c044ae:1:9]<352:05:17:26.955312>[17]: [init]: rest_gateway is active}

  // In file, we usually write only the part after "xxx, ". To make it work as expected, simulate syslog message by adding
  // "pg:" to each message.
  var new_message = "xxx, " + message.toString();
  sendRiemann(client, new_message);
    console.log(new_message);
})
rl.on('close', function() {
client.disconnect();
})
