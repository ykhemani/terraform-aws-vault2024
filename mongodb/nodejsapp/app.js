// require the necessary libraries
const { faker } = require("@faker-js/faker");
const MongoClient = require("mongodb").MongoClient;

function randomIntFromInterval(min, max) { // min and max included 
    return Math.floor(Math.random() * (max - min + 1) + min);
}

async function seedDB() {
    // Connection URL
    const uri = "mongodb://" + process.env.MONGODB_ROOT_USERNAME + ":" + process.env.MONGODB_ROOT_PASSWORD + "@" + process.env.MONGODB_URL;

    const client = new MongoClient(uri, { tlsCAFile: `/data/certs/wildcard/ca.pem` } );

    try {
        await client.connect();
        console.log("Connected correctly to server");

        const collection = client.db("demodb").collection("synthetic_data");

        // make a bunch of time series data
        let timeSeriesData = [];

        for (let i = 0; i < 10; i++) {
            const firstName = faker.person.firstName();
            const lastName = faker.person.lastName();
            let newDay = {
                timestamp_day: faker.date.past(),
                cat: faker.lorem.word(),
                owner: {
                    email: faker.internet.email({firstName, lastName}),
                    firstName,
                    lastName,
                },
                events: [],
            };

            for (let j = 0; j < randomIntFromInterval(1, 6); j++) {
                let newEvent = {
                    timestamp_event: faker.date.past(),
                    weight: randomIntFromInterval(14,16),
                }
                newDay.events.push(newEvent);
            }
            timeSeriesData.push(newDay);
        }
        await collection.insertMany(timeSeriesData);

        console.log("Database seeded with synthetic data! :)");
        process.exit();
    } catch (err) {
        console.log(err.stack);
    }
}

seedDB();

