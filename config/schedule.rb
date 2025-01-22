every 1.day, at: '9:00 am' do
  runner "Cron::NettingBatch.run"
end