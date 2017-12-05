const monk = require('monk')
const db = monk(process.env.MONGODB_URL)

const calls = db.get('calls')

calls
  .find({ timestamp: { $eq: null } })
  .then(results => {
    const updates = results.map(({ _id }) => {
      const raw = _id.toString().substring(0, 8)
      const as_int = parseInt(raw, 16)
      const timestamp = new Date(as_int * 1000)

      return {
        updateOne: {
          filter: { _id },
          update: { $set: { timestamp } },
          upsert: false
        }
      }
    })

    calls
      .bulkWrite(updates)
      .then(writeResult => {
        console.log(writeResult)
      })
      .catch(console.error)
  })
  .catch(console.error)

a = [
  ({
    $project: {
      contact: '$contact',
      'timestamp~~~day': {
        $let: {
          vars: { field: '$timestamp' },
          in: {
            ___date: { $dateToString: { format: '%Y-%m-%d', date: '$$field' } }
          }
        }
      }
    }
  },
  {
    $match: {
      $and: [
        { contact: { $eq: true } },
        { 'timestamp~~~day': { $eq: { ___date: '2017-12-03' } } }
      ]
    }
  },
  { $group: { _id: null, count: { $sum: 1 } } },
  { $sort: { _id: 1 } },
  { $project: { _id: false, count: true } })
]
